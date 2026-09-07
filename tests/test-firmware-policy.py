"""Test launcher firmware refusals locally without disks, KVM, or root access."""
import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
GIT_BASH = Path('C:/Program Files/Git/bin/bash.exe')
BASH = str(GIT_BASH) if os.name == 'nt' and GIT_BASH.exists() else shutil.which('bash')


class FirmwarePolicyTests(unittest.TestCase):
    def run_launcher(self, script, mode):
        self.assertIsNotNone(BASH, 'Bash is required for these tests')
        env = os.environ.copy()
        for name in ('FIRMWARE_MODE', 'GUEST_CIDR', 'GUEST_GATEWAY'):
            env.pop(name, None)
        # Valid BIOS stops at approval/root/network checks, before any disk access.
        env.update(ERASE_CONFIRMED='NO', CHECK_ONLY='1')
        if mode is not None:
            env['FIRMWARE_MODE'] = mode
        return subprocess.run(
            [BASH, str(ROOT / script)], env=env, capture_output=True, text=True, timeout=10
        )

    def test_unsupported_modes_are_refused_before_prerequisites(self):
        for script in ('install-qemu.sh', 'boot-installed-qemu.sh'):
            for mode in (None, '', 'uefi', 'automatic', 'BIOS'):
                with self.subTest(script=script, mode=mode):
                    result = self.run_launcher(script, mode)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('Legacy BIOS is mandatory', result.stderr)

    def test_bios_reaches_the_next_guard(self):
        for script in ('install-qemu.sh', 'boot-installed-qemu.sh'):
            with self.subTest(script=script):
                result = self.run_launcher(script, 'bios')
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('Legacy BIOS is mandatory', result.stderr)
                self.assertTrue(any(message in result.stderr for message in (
                    'Run as root', 'Set ERASE_CONFIRMED=YES',
                    'Set the installed IPv4 CIDR', 'Rescue is booted in UEFI',
                )), result.stderr)


if __name__ == '__main__':
    unittest.main()
