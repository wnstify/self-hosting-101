"""Check public-key validation locally with synthetic public data and mocked hashing."""
import base64
from contextlib import redirect_stderr, redirect_stdout
import io
import os
from pathlib import Path
import runpy
import struct
import subprocess
import tempfile
import tomllib
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
HASH = '$6$synthetic$not-a-real-password-hash'
PASSWORD = 'synthetic-test-password'


def public_key(byte):
    # SSH public-key encoding needs no private key for these parser tests.
    kind = b'ssh-ed25519'
    blob = struct.pack('>I', len(kind)) + kind + struct.pack('>I', 32) + bytes([byte]) * 32
    return 'ssh-ed25519 ' + base64.b64encode(blob).decode('ascii')


class AnswerCredentialsTests(unittest.TestCase):
    def run_helper(self, key_text):
        actual_run = subprocess.run
        hash_calls = []

        def run_command(command, **kwargs):
            if command[0] == 'openssl':
                hash_calls.append((command, kwargs))
                return subprocess.CompletedProcess(command, 0, stdout=HASH + '\n')
            self.assertEqual(command[:2], ['ssh-keygen', '-lf'])
            return actual_run(command, **kwargs)

        with tempfile.TemporaryDirectory() as temporary:
            answer = Path(temporary) / 'answer.toml'
            original = (ROOT / 'answer.toml.example').read_bytes()
            answer.write_bytes(original)
            keys = Path(temporary) / 'keys.pub'
            keys.write_text(key_text)
            stdout, stderr = io.StringIO(), io.StringIO()
            status = 0
            saved_umask = os.umask(0o077)
            try:
                with (
                    patch('sys.argv', ['set-answer-credentials.py', str(answer), str(keys)]),
                    patch('getpass.getpass', return_value=PASSWORD) as get_password,
                    patch('subprocess.run', side_effect=run_command),
                    redirect_stdout(stdout),
                    redirect_stderr(stderr),
                ):
                    try:
                        runpy.run_path(str(ROOT / 'set-answer-credentials.py'), run_name='__main__')
                    except SystemExit as error:
                        status = error.code
            finally:
                os.umask(saved_umask)
            return {
                'status': status,
                'answer': answer.read_bytes(),
                'original': original,
                'output': stdout.getvalue() + stderr.getvalue(),
                'password_prompts': get_password.call_count,
                'hash_calls': hash_calls,
            }

    def assert_rejected(self, result, message):
        self.assertEqual(result['status'], 2)
        self.assertIn(message, result['output'])
        self.assertEqual(result['answer'], result['original'])
        self.assertEqual(result['password_prompts'], 0)
        self.assertEqual(result['hash_calls'], [])

    def test_mixed_valid_and_malformed_keys_are_rejected_before_password_prompt(self):
        valid = public_key(0)
        malformed = 'ssh-ed25519 definitely-invalid-base64'
        result = self.run_helper('# approved keys\n' + valid + '\n' + malformed + '\n')
        self.assert_rejected(result, 'Invalid SSH public key on line 3')
        self.assertNotIn(valid, result['output'])
        self.assertNotIn(malformed, result['output'])

    def test_malformed_key_is_rejected(self):
        result = self.run_helper('ssh-ed25519 definitely-invalid-base64\n')
        self.assert_rejected(result, 'Invalid SSH public key on line 1')

    def test_empty_and_comment_only_files_are_rejected(self):
        for text in ('', '\n  # no keys yet\n'):
            with self.subTest(text=text):
                self.assert_rejected(self.run_helper(text), 'No public keys found')

    def test_authorized_keys_options_are_rejected(self):
        result = self.run_helper('restrict ' + public_key(0) + '\n')
        self.assert_rejected(result, 'Public-key line 1: use a plain SSH public key without authorized_keys options')

    def test_multiple_valid_keys_keep_the_existing_hashing_workflow(self):
        keys = [public_key(0), public_key(1)]
        result = self.run_helper('# approved keys\n' + keys[0] + ' first comment\n\n' + keys[1] + ' second comment\n')
        self.assertEqual(result['status'], 0, result['output'])
        answer = tomllib.loads(result['answer'].decode())
        self.assertEqual(answer['global']['root-ssh-keys'], keys)
        self.assertEqual(answer['global']['root-password-hashed'], HASH)
        self.assertEqual(result['password_prompts'], 2)
        self.assertEqual(result['hash_calls'], [(
            ['openssl', 'passwd', '-6', '-stdin'],
            {'input': PASSWORD + '\n', 'text': True, 'capture_output': True, 'check': True},
        )])
        self.assertNotIn(PASSWORD, result['output'])
        self.assertNotIn(HASH, result['output'])


if __name__ == '__main__':
    unittest.main()
