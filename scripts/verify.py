#!/usr/bin/env python3
"""Run local acceptance checks and retain sanitized results without publishing."""
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
os.chdir(root)
commands = [
    ["moon", "version", "--all"],
    ["moon", "fmt"],
    ["moon", "fmt", "--check"],
    ["moon", "check", "--deny-warn", "--target", "native"],
    ["moon", "test", "--deny-warn", "--target", "native"],
    ["moon", "check", "--deny-warn", "--target", "js"],
    ["moon", "test", "--deny-warn", "--target", "js"],
    ["moon", "check", "--deny-warn", "--target", "wasm-gc"],
    ["moon", "test", "--deny-warn", "--target", "wasm-gc"],
    ["python3", "scripts/validate-model.py"],
    ["python3", "scripts/test-cli.py"],
    ["moon", "run", "cmd/main", "--target", "native", "--", "samples/standard.json"],
    ["moon", "package", "--list"],
    ["moon", "package"],
    ["python3", "scripts/check-personal-data.py"],
]
records = []
failed = False
for command in commands:
    result = subprocess.run(command, text=True, capture_output=True)
    stdout = result.stdout.replace(str(root), "<module>").replace(str(Path.home()), "<home>")
    stderr = result.stderr.replace(str(root), "<module>").replace(str(Path.home()), "<home>")
    if command == ["moon", "package", "--list"] and result.returncode == 0:
        entries = (stdout + stderr).splitlines()
        unexpected = [entry for entry in entries if
            entry.startswith(("audit/", "closeout-audit/", ".validation-cache/")) or
            (entry.startswith("evidence/") and entry != "evidence/schema-sources.json") or
            entry.endswith(".bundle")]
        if unexpected or "models/insurance.dmn" not in entries or "model_generated.mbt" not in entries or "evidence/schema-sources.json" not in entries:
            result.returncode = 1
            stderr += "Unexpected package contents: " + repr(unexpected)
    records.append({
        "command": command, "exit_code": result.returncode,
        "status": "passed" if result.returncode == 0 else "failed",
        "stdout": stdout, "stderr": stderr,
    })
    print(" ".join(command) + ": " + records[-1]["status"], flush=True)
    if result.returncode != 0:
        print(stdout + stderr)
        failed = True
        break
(root / "evidence/validation.json").write_text(json.dumps(records, indent=2) + "\n")
raise SystemExit(1 if failed else 0)
