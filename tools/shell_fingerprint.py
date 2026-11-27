"""Changes to the embedded shell require a new ABI and APK."""
import hashlib
import os
import pathlib
import re

h = hashlib.sha256()
h.update(os.environ["GODOT_VERSION"].encode())
paths = sorted(pathlib.Path("game/bootstrap").glob("*"))
paths += [pathlib.Path("game/project.godot"), pathlib.Path("game/export_presets.cfg")]
for p in paths:
    if not p.is_file() or p.suffix == ".uid":
        continue
    data = p.read_text()
    data = re.sub(r"^(config/version|version/name|version/code)=.*$", "", data, flags=re.M)
    h.update(p.as_posix().encode())
    h.update(data.encode())
print(h.hexdigest())
