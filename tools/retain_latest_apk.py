"""Keep only the verified newest lab release binary; never delete source tags."""
import json
import os
import re
import subprocess
import sys

def gh(*args):
    return subprocess.check_output(["gh", *args], text=True)

def pages(endpoint):
    return json.loads(gh("api", "--paginate", "--slurp", endpoint))

def main():
    tag, apk = sys.argv[1:]
    repo = os.environ["GITHUB_REPOSITORY"]
    if not (re.fullmatch(r"lab-alpha-\d+", tag) or tag == "lab-shell-v1") or not re.fullmatch(r"MyGame-Lab-[0-9A-Za-z.-]+\.apk", apk):
        raise ValueError("Unexpected release identity")
    release = json.loads(gh("api", f"repos/{repo}/releases/tags/{tag}"))
    assets = release["assets"]
    if not any(a["name"] == apk and a["state"] == "uploaded" and a["size"] > 0 for a in assets):
        raise RuntimeError("New APK not verified as uploaded; refusing cleanup")
    if not any(a["name"] == "SHA256SUMS.txt" and a["state"] == "uploaded" for a in assets):
        raise RuntimeError("Missing checksum; refusing cleanup")
    old = []
    for page in pages(f"repos/{repo}/releases?per_page=100"):
        for item in page:
            old_tag = item["tag_name"]
            if not re.fullmatch(r"lab-alpha-\d+", old_tag) or (tag != "lab-shell-v1" and int(old_tag.rsplit("-", 1)[1]) >= int(tag.rsplit("-", 1)[1])):
                continue
            for a in item["assets"]:
                if re.fullmatch(r"MyGame-Lab(?:-[0-9A-Za-z.-]+)?\.apk", a["name"]) or a["name"] == "SHA256SUMS.txt":
                    old.append((a["id"], old_tag, a["name"]))
    for asset_id, old_tag, name in old:
        gh("api", "--method", "DELETE", f"repos/{repo}/releases/assets/{asset_id}")
        print(f"Removed old binary/checksum: {old_tag}/{name}")
    for page in pages(f"repos/{repo}/actions/artifacts?per_page=100"):
        for a in page["artifacts"]:
            if a["name"] == "MyGame-Lab-Android" and (tag == "lab-shell-v1" or a.get("workflow_run", {}).get("id", 0) < int(tag.rsplit("-", 1)[1])):
                gh("api", "--method", "DELETE", f"repos/{repo}/actions/artifacts/{a['id']}")
                print(f"Removed redundant old APK artifact {a['id']}")
    print("RETENTION_OK: newest verified release retained; source tags untouched.")

if __name__ == "__main__":
    main()
