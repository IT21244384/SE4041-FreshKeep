"""Reads `xcrun simctl list devices available --json` from stdin and prints the UDID
of the newest-runtime device whose name starts with the given prefix."""
import json
import re
import sys

prefix = sys.argv[1] if len(sys.argv) > 1 else "iPhone"
data = json.load(sys.stdin)


def version(runtime):
    match = re.search(r"(\d+)-(\d+)", runtime)
    return tuple(int(x) for x in match.groups()) if match else (0, 0)


candidates = []
for runtime, devices in data["devices"].items():
    for device in devices:
        name = device["name"]
        if name.startswith(prefix) and device.get("isAvailable", True):
            # Prefer plain/Pro phones over SE/mini for consistent screenshots.
            penalty = 1 if any(x in name.split() for x in ("SE", "mini", "Plus", "Max", "Air")) or name.endswith("e") else 0
            candidates.append((version(runtime), -penalty, name, device["udid"]))

if not candidates:
    sys.exit(f"No simulator found for {prefix}")
candidates.sort()
print(candidates[-1][3])
print(f"Picked {candidates[-1][2]} {candidates[-1][0]}", file=sys.stderr)
