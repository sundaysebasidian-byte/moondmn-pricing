#!/usr/bin/env python3
"""Process-level assertions against the hand-derived sample and error contract."""
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parent.parent
CLI = ROOT / "_build/native/debug/build/cmd/main/main.exe"


class CliTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(["moon", "build", "--target", "native", "cmd/main"], cwd=ROOT, check=True)

    def run_cli(self, *args):
        return subprocess.run([str(CLI), *args], cwd=ROOT, text=True, capture_output=True)

    def test_sample_exact_bytes_twice(self):
        expected = (ROOT / "samples/standard.expected.json").read_text()
        for _ in range(2):
            result = self.run_cli("samples/standard.json")
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, expected)
            self.assertEqual(result.stderr, "")

    def test_usage_and_extra_argument(self):
        for args in [(), ("samples/standard.json", "extra")]:
            result = self.run_cli(*args)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(json.loads(result.stdout)["error"], "E_USAGE")

    def test_unreadable_file(self):
        result = self.run_cli("samples/does-not-exist.json")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)["error"], "E_IO")

    def test_invalid_inputs(self):
        cache = ROOT / ".validation-cache"
        cache.mkdir(exist_ok=True)
        path = cache / "cli-invalid-input.json"
        for text, code in [("{", "E_INPUT_JSON"), ("{}", "E_INPUT"), ("null", "E_INPUT")]:
            path.write_text(text)
            result = self.run_cli(str(path))
            self.assertEqual(result.returncode, 1)
            self.assertEqual(json.loads(result.stdout)["error"], code)
            self.assertEqual(result.stderr, "")

    def test_strict_json_and_engine_errors(self):
        sample = (ROOT / "samples/standard.json").read_text().strip()
        cache = ROOT / ".validation-cache"
        cache.mkdir(exist_ok=True)
        path = cache / "cli-engine-error.json"
        cases = [
            (sample[:-1] + ',"age":50}', "E_JSON"),
            (sample.replace("20000", "1e1000001"), "E_DECIMAL_RANGE"),
            (sample.replace("20000", "1" * 10001), "E_DECIMAL_SYNTAX"),
            (sample.replace("2026-01-01", str(10**9 - 1) + "-12-31"), "E_DATE_RANGE"),
        ]
        for text, code in cases:
            with self.subTest(code=code):
                path.write_text(text)
                result = self.run_cli(str(path))
                self.assertEqual(result.returncode, 1)
                self.assertEqual(json.loads(result.stdout)["error"], code)
                self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main()
