"""Acquire locked CC0 archives, retain originals, and extract engine-ready GLBs."""
import hashlib
import json
import pathlib
import shutil
import tempfile
import urllib.request
import zipfile
import struct

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / "assets/catalog/initial-lock.json").read_text())
SOURCE = ROOT / "assets/source/cc0"
RUNTIME = ROOT / "game/assets/runtime"

def verified(path, pack):
    return path.stat().st_size == pack["bytes"] and hashlib.sha256(path.read_bytes()).hexdigest() == pack["sha256"]

def acquire(pack):
    dest = SOURCE / pack["id"] / pack["archive"]
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists():
        with tempfile.NamedTemporaryFile(dir=dest.parent, delete=False) as tmp:
            temp = pathlib.Path(tmp.name)
            try:
                with urllib.request.urlopen(LOCK["mirror"] + pack["archive"], timeout=90) as response:
                    # Reject oversized or unexpected files.
                    data = response.read(pack["bytes"] + 1)
                    tmp.write(data)
                tmp.close()
                if not verified(temp, pack):
                    raise ValueError(f"Archive integrity mismatch: {pack['id']}")
                temp.replace(dest)
            finally:
                temp.unlink(missing_ok=True)
    if not verified(dest, pack):
        raise ValueError(f"Archive integrity mismatch: {pack['id']}")
    (dest.parent / "PROVENANCE.json").write_text(json.dumps(pack, indent=2) + "\n")
    return dest

def glb_metadata(data):
    if len(data) < 20 or data[:4] != b"glTF":
        raise ValueError("Invalid GLB")
    version, total, size, kind = struct.unpack_from("<4I", data, 4)
    if version != 2 or total != len(data) or kind != 0x4E4F534A or size > len(data)-20:
        raise ValueError("Invalid GLB header")
    return json.loads(data[20:20+size])

def prepare(pack):
    archive = acquire(pack)
    candidates = []
    with zipfile.ZipFile(archive) as z:
        for entry in z.infolist():
            path = pathlib.PurePosixPath(entry.filename.replace("\\", "/"))
            if path.is_absolute() or ".." in path.parts or entry.file_size > 100_000_000:
                raise ValueError("Unsafe archive entry")
            if entry.is_dir():
                continue
            if path.suffix.lower() == ".txt" and ("license" in path.name.lower() or "readme" in path.name.lower()):
                target = archive.parent / "notices" / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(z.read(entry))
            if path.suffix.lower() != ".glb":
                continue
            data = z.read(entry)
            meta = glb_metadata(data)
            if not meta.get("animations") or not meta.get("meshes") or not meta.get("skins"):
                continue
            low = str(path).lower()
            score = (("godot" in low), ("unity" not in low), ("no root" in low or "in place" in low or "noroot" in low or "inplace" in low), len(meta["animations"]))
            candidates.append((score, str(path), data, meta))
    if not candidates:
        raise ValueError(f"No rigged animated GLB: {pack['id']}")
    # Include all distinct animated GLBs, prefer Godot-compatible variant first.
    seen = set()
    records = []
    for _, original, data, meta in sorted(candidates, key=lambda x:(x[0], x[1]), reverse=True):
        sha = hashlib.sha256(data).hexdigest()
        if sha in seen:
            continue
        seen.add(sha)
        name = f"{pack['id']}-{sha[:12]}.glb"
        (RUNTIME / name).write_bytes(data)
        records.append({"id": name[:-4], "path": f"res://assets/runtime/{name}", "sourcePath": original, "pack": pack["id"], "sha256": sha, "clips": [a.get("name", str(i)) for i,a in enumerate(meta["animations"])], "license": pack["license"]})
    return records

def prepare_items():
    """Verified preconverted GLBs from an immutable, CC0 mirror."""
    lock = json.loads((ROOT / "assets/catalog/items-lock.json").read_text())
    records = []
    for pack in lock["packs"]:
        source = SOURCE / pack["id"]
        source.mkdir(parents=True, exist_ok=True)
        (source / "PROVENANCE.json").write_text(json.dumps({
            "repository": lock["repository"], "revision": lock["revision"],
            "licenseSource": lock["licenseSource"], "pack": pack
        }, indent=2) + "\n")
        for entry in pack["files"]:
            name = entry["name"]
            if pathlib.PurePosixPath(name).name != name or not name.endswith(".glb"):
                raise ValueError("Invalid item name")
            dest = source / name
            if dest.exists():
                data = dest.read_bytes()
            else:
                url = f"https://raw.githubusercontent.com/{lock['repository']}/{lock['revision']}/{entry['path']}"
                with urllib.request.urlopen(url, timeout=60) as response:
                    data = response.read(entry["bytes"] + 1)
            blob = hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()
            if len(data) != entry["bytes"] or blob != entry["gitBlob"]:
                raise ValueError(f"Item integrity mismatch: {name}")
            meta = glb_metadata(data)
            if not meta.get("meshes"):
                raise ValueError(f"Item without mesh: {name}")
            if any("uri" in x and not x["uri"].startswith("data:") for x in meta.get("images", []) + meta.get("buffers", [])):
                raise ValueError(f"External GLB dependency: {name}")
            if not dest.exists():
                dest.write_bytes(data)
            runtime_name = f"item-{pack['id']}-{name}"
            (RUNTIME / runtime_name).write_bytes(data)
            records.append({
                "id": runtime_name[:-4], "path": f"res://assets/runtime/{runtime_name}",
                "name": name[:-4], "pack": pack["id"], "license": pack["license"],
                "sha256": hashlib.sha256(data).hexdigest()
            })
    (RUNTIME / "items.json").write_text(json.dumps(records, indent=2) + "\n")
    print(f"Prepared {len(records)} item models.")

def main():
    RUNTIME.mkdir(parents=True, exist_ok=True)
    for old in RUNTIME.glob("ual*-*.glb"):
        old.unlink()
    records = []
    for pack in LOCK["packs"]:
        records.extend(prepare(pack))
    (RUNTIME / "catalog.json").write_text(json.dumps(records, indent=2) + "\n")
    print(f"Prepared {len(records)} animated scenes; {sum(len(r['clips']) for r in records)} clip instances (variants counted).")
    for old in RUNTIME.glob("item-*.glb"):
        old.unlink()
    prepare_items()

if __name__ == "__main__":
    main()
