"""Retain two newest content packs; verify the new upload before pruning."""
import json
import os
import re
import subprocess
import sys

def gh(*args):
    return subprocess.check_output(["gh", *args], text=True)

repo = os.environ["GITHUB_REPOSITORY"]
name = sys.argv[1]
release = json.loads(gh("api", f"repos/{repo}/releases/tags/lab-content-v1"))
assets = release["assets"]
assert any(a["name"] == name and a["state"] == "uploaded" and a["size"] > 0 and str(a.get("digest", "")).startswith("sha256:") for a in assets)
packs = []
for a in assets:
    m = re.fullmatch(r"MyGame-content-0\.1\.0-alpha\.(\d+)-(\d+)\.pck", a["name"])
    if m:
        packs.append((int(m[1]), int(m[2]), a))
packs.sort(key=lambda x: x[:2], reverse=True)
for _, _, a in packs[2:]:
    if a["name"] != name:
        gh("api", "--method", "DELETE", f"repos/{repo}/releases/assets/{a['id']}")
