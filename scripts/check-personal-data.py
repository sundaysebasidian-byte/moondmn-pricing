#!/usr/bin/env python3
"""Grep deliverable text for email/phone patterns and the local account name."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parent.parent
paths = subprocess.check_output([
    "git", "ls-files", "--cached", "--others", "--exclude-standard", "-z",
], cwd=root).decode().split("\0")
patterns = {
    "email": re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
    "phone": re.compile(r"(?<![\w])\+?\d(?:[ ().-]*\d){9,14}(?![\w])"),
    "account name": re.compile(r"(?<![\w-])" + re.escape(Path.home().name) + r"(?![\w-])", re.I),
}
failures = []
for name in sorted(set(filter(None, paths))):
    text = (root / name).read_text()
    for label, pattern in patterns.items():
        for line, value in enumerate(text.splitlines(), 1):
            candidate = value.replace("0.1.20261104", "TOOLCHAIN") if label == "phone" else value
            if pattern.search(candidate):
                failures.append(f"{name}:{line}: {label} pattern")
if failures:
    raise SystemExit("\n".join(failures))
print(f"Personal-data grep clean: {len(set(filter(None, paths)))} deliverable files")
