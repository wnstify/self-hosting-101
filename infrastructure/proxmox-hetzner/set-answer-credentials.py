#!/usr/bin/env python3
"""Insert a password hash and SSH public keys into a private installer answer."""
import argparse
import getpass
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import tomllib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('answer', type=Path)
parser.add_argument('public_keys', type=Path)
parser.add_argument('--random-password', action='store_true', help='Hash a random password and discard it; set a usable password later over SSH')
args = parser.parse_args()
os.umask(0o077)
text = args.answer.read_text()
if 'REPLACE_WITH_SHA512_CRYPT_HASH' not in text or '"REPLACE_WITH_SSH_PUBLIC_KEY"' not in text:
    parser.error('Expected the REPLACE_WITH_SHA512_CRYPT_HASH and REPLACE_WITH_SSH_PUBLIC_KEY placeholders. Start from a fresh copy of answer.toml.example.')
keys = []
for line_number, line in enumerate(args.public_keys.read_text().splitlines(), start=1):
    if not line.strip() or line.lstrip().startswith('#'):
        continue
    parts = line.split()
    if len(parts) < 2 or not parts[0].startswith(('ssh-', 'ecdsa-', 'sk-')):
        parser.error(f'Public-key line {line_number}: use a plain SSH public key without authorized_keys options')
    key = ' '.join(parts[:2])
    with tempfile.TemporaryDirectory(prefix='proxmox-public-key-') as temporary:
        key_path = Path(temporary) / 'key.pub'
        key_path.write_text(key + '\n')
        try:
            result = subprocess.run(['ssh-keygen', '-lf', str(key_path)], capture_output=True)
        except FileNotFoundError:
            parser.error('ssh-keygen is required to validate public keys')
    if result.returncode:
        parser.error(f'Invalid SSH public key on line {line_number}')
    keys.append(key)
if not keys:
    parser.error('No public keys found')
if args.random_password:
    password = secrets.token_urlsafe(40)
else:
    password = getpass.getpass('Root password (stored only as a hash): ')
    if len(password) < 16:
        parser.error('Use a password of at least 16 characters')
    if password != getpass.getpass('Confirm root password: '):
        parser.error('Passwords did not match')
try:
    hashed = subprocess.run(['openssl', 'passwd', '-6', '-stdin'], input=password + '\n', text=True, capture_output=True, check=True).stdout.strip()
except FileNotFoundError:
    parser.error('openssl is required to hash the password')
text = text.replace('REPLACE_WITH_SHA512_CRYPT_HASH', hashed)
text = text.replace('"REPLACE_WITH_SSH_PUBLIC_KEY"', ',\n    '.join(json.dumps(key) for key in keys))
tomllib.loads(text)
args.answer.chmod(0o600)
args.answer.write_text(text)
print(f'SSH public keys inserted: {len(keys)}. No password or hash printed.')
if args.random_password:
    print('Random password discarded. Use SSH to set a usable root password before GUI login.')
