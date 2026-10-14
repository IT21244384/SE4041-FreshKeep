"""xcresulttool exports attachments with UUID file names plus a manifest.json.
This renames each screenshot to the name given in the UI test (e.g. 03-pantry.png)."""
import json
import os
import sys

folder = sys.argv[1]
manifest_path = os.path.join(folder, "manifest.json")
with open(manifest_path, encoding="utf-8") as f:
    manifest = json.load(f)

for test in manifest:
    for attachment in test.get("attachments", []):
        exported = attachment.get("exportedFileName")
        suggested = attachment.get("suggestedHumanReadableName", exported)
        # suggestedHumanReadableName looks like "03-pantry_0_<UUID>.png"; keep the readable part.
        base = suggested.split("_0_")[0]
        ext = os.path.splitext(exported)[1]
        source = os.path.join(folder, exported)
        if os.path.exists(source):
            os.replace(source, os.path.join(folder, base + ext))
# Remove characters GitHub artifact upload rejects (quotes, colons, etc.).
bad = set('"<>:|*?') | {chr(13), chr(10)}

for name in os.listdir(folder):
    clean = "".join("_" if c in bad else c for c in name)
    if clean != name:
        os.replace(os.path.join(folder, name), os.path.join(folder, clean))
print("Renamed attachments")
