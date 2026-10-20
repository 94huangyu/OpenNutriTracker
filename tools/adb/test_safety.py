"""Device-tool entry-point regression; uses fake tools, never a real device."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent
BASH = shutil.which("bash")


class DeviceToolSafetyTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ont-adb-safety-")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.calls = self.folder / "calls"
        for name in ("adb", "git", "fvm", "flutter", "cp", "rm"):
            tool = self.folder / name
            tool.write_text(
                '#!/bin/sh\nprintf "%s\\n" "$0 $*" >> "$ONT_TOOL_CALL_LOG"\nexit 97\n'
            )
            tool.chmod(0o700)
        self.env = os.environ.copy()
        for key in ("DEVICE", "BASH_ENV", "ENV"):
            self.env.pop(key, None)
        self.env["PATH"] = str(self.folder) + os.pathsep + self.env.get("PATH", "")
        self.env["ONT_TOOL_CALL_LOG"] = str(self.calls)

    def run_tool(self, name, *, sourced=False, device=None):
        env = self.env.copy()
        if device is not None:
            env["DEVICE"] = device
            env["PACKAGE"] = "com.example.test"
            env["ALLOW_DESTRUCTIVE_TESTS"] = "1"
        if sourced:
            args = [
                BASH, "-c",
                'source "$1"; status=$?; printf "caller-survived\\n"; exit "$status"',
                "safety-test", str(ROOT / name),
            ]
        else:
            args = [BASH, str(ROOT / name)]
        result = subprocess.run(
            args, env=env, cwd=self.folder, capture_output=True, text=True, timeout=5
        )
        self.assertFalse(self.calls.exists(), result.stdout + result.stderr)
        if sourced:
            self.assertIn("caller-survived", result.stdout)
        return result

    def assert_retired(self, name, **kwargs):
        result = self.run_tool(name, **kwargs)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("已在本Fork停用", result.stderr)

    def test_onboarding_direct(self):
        self.assert_retired("walk-onboarding.sh")

    def test_onboarding_sourced(self):
        self.assert_retired("walk-onboarding.sh", sourced=True)

    def test_branch_runner_direct(self):
        self.assert_retired("run-branch-tests.sh")

    def test_branch_runner_sourced(self):
        self.assert_retired("run-branch-tests.sh", sourced=True)

    def test_device_and_opt_in_cannot_bypass_retirement(self):
        for name in ("walk-onboarding.sh", "run-branch-tests.sh"):
            with self.subTest(script=name):
                self.assert_retired(name, device="fake-device")

    def test_driver_requires_explicit_device_when_executed(self):
        result = self.run_tool("adb-driver.sh")
        self.assertEqual(result.returncode, 2)
        self.assertIn("必须显式设置", result.stderr)

    def test_driver_requires_explicit_device_when_sourced(self):
        result = self.run_tool("adb-driver.sh", sourced=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("必须显式设置", result.stderr)

    def test_sourcing_driver_with_device_does_not_contact_device(self):
        result = self.run_tool("adb-driver.sh", sourced=True, device="fake-device")
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
