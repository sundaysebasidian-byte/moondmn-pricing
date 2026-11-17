#!/usr/bin/env python3
"""Run local acceptance checks, retaining sanitized results and the dry-run limit."""
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
os.chdir(root)
os.environ["MOON_HOME"] = "/tmp/moon-new"
os.environ["PATH"] = "/tmp/moon-new/bin:" + os.environ["PATH"]
commands = [
    ["moon", "version", "--all"],
    ["moon", "fmt"],
    ["moon", "fmt", "--check"],
    ["moon", "check", "--deny-warn"],
    ["moon", "test"],
    ["moon", "check", "--deny-warn", "--target", "js"],
    ["moon", "test", "--target", "js"],
    ["moon", "check", "--deny-warn", "--target", "wasm-gc"],
    ["moon", "test", "--target", "wasm-gc"],
    ["python3", "scripts/validate-model.py"],
    ["python3", "scripts/test-cli.py"],
    ["moon", "run", "cmd/main", "--target", "native", "--", "samples/standard.json"],
    ["moon", "package", "--list"],
    ["moon", "package"],
    ["python3", "scripts/check-personal-data.py"],
    ["moon", "publish", "--dry-run"],
]
records = []
failed = False
for command in commands:
    result = subprocess.run(command, text=True, capture_output=True)
    stdout = result.stdout.replace(str(root), "<module>").replace(str(Path.home()), "<home>")
    stderr = result.stderr.replace(str(root), "<module>").replace(str(Path.home()), "<home>")
    expected_block = command == ["moon", "publish", "--dry-run"] and result.returncode != 0 and "Registry login is required" in stdout + stderr
    records.append({
        "command": command, "exit_code": result.returncode,
        "status": "blocked_no_credentials" if expected_block else "passed" if result.returncode == 0 else "failed",
        "stdout": stdout, "stderr": stderr,
    })
    print(" ".join(command) + ": " + records[-1]["status"], flush=True)
    if result.returncode != 0 and not expected_block:
        print(stdout + stderr)
        failed = True
        break
(root / "evidence/validation.json").write_text(json.dumps(records, indent=2) + "\n")
raise SystemExit(1 if failed else 0)
