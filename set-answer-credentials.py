#!/usr/bin/env python3
"""Insert a password hash and SSH public keys into a private installer answer."""
import argparse
import getpass
import json
import os
from pathlib import Path
import secrets
import subprocess
import tomllib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('answer', type=Path)
parser.add_argument('public_keys', type=Path)
parser.add_argument('--random-password', action='store_true', help='Discard a random password after hashing; provision a usable password later over SSH')
args = parser.parse_args()
os.umask(0o077)
text = args.answer.read_text()
if 'REPLACE_WITH_SHA512_CRYPT_HASH' not in text or 'REPLACE_WITH_SSH_PUBLIC_KEY' not in text:
    parser.error('Expected credential placeholders in the answer file')
keys = []
for line in args.public_keys.read_text().splitlines():
    if not line.strip() or line.lstrip().startswith('#'):
        continue
    parts = line.split()
    if len(parts) < 2 or not parts[0].startswith(('ssh-', 'ecdsa-', 'sk-')):
        parser.error('Use plain SSH public-key lines, without authorized_keys options')
    keys.append(' '.join(parts[:2]))
if not keys:
    parser.error('No public keys found')
result = subprocess.run(['ssh-keygen', '-lf', str(args.public_keys)], capture_output=True)
if result.returncode:
    parser.error('ssh-keygen could not validate the public-key file')
if args.random_password:
    password = secrets.token_urlsafe(40)
else:
    password = getpass.getpass('Root password (stored only as a hash): ')
    if len(password) < 16:
        parser.error('Use a password of at least 16 characters')
    if password != getpass.getpass('Confirm root password: '):
        parser.error('Passwords did not match')
hashed = subprocess.run(['openssl', 'passwd', '-6', '-stdin'], input=password + '\n', text=True, capture_output=True, check=True).stdout.strip()
text = text.replace('REPLACE_WITH_SHA512_CRYPT_HASH', hashed)
text = text.replace('"REPLACE_WITH_SSH_PUBLIC_KEY"', ',\n    '.join(json.dumps(key) for key in keys))
tomllib.loads(text)
args.answer.chmod(0o600)
args.answer.write_text(text)
print(f'Credentials inserted; {len(keys)} public key(s); no password or hash printed')
if args.random_password:
    print('Random password discarded. Use SSH to set a usable root password before GUI login.')
