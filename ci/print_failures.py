"""Prints failed tests and their failure messages from
`xcrun xcresulttool get test-results tests --compact` JSON (path given as argv[1])."""
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)


def walk(node, trail):
    name = node.get("name", "")
    kind = node.get("nodeType", "")
    if kind == "Failure Message":
        print(f"FAIL {' > '.join(trail)}: {name}")
    for child in node.get("children", []):
        walk(child, trail + ([name] if kind in ("Test Case", "Test Suite") else []))


for root in data.get("testNodes", []):
    walk(root, [])
