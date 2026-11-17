#!/usr/bin/env python3
"""Validate with pinned copies of the official OMG DMN 1.3 schemas."""
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.request import urlopen

root = Path(__file__).resolve().parent.parent
cache = root / ".validation-cache"
cache.mkdir(exist_ok=True)
for entry in json.loads((root / "evidence/schema-sources.json").read_text()):
    path = cache / entry["file"]
    if not path.exists():
        with urlopen(entry["url"], timeout=30) as response:
            path.write_bytes(response.read())
    if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
        raise SystemExit("schema checksum mismatch: " + entry["file"])
subprocess.run([
    "xmllint", "--noout", "--schema", str(cache / "DMN13.xsd"),
    "models/insurance.dmn",
], cwd=root, check=True)
