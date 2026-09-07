#!/usr/bin/env python3
"""Save a screenshot through QEMU's private Unix monitor socket in Rescue."""
import argparse
import os
from pathlib import Path
import socket
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir', default='/tmp/proxmox-auto')
args = parser.parse_args()
work = Path(args.work_dir).resolve()
output = work / 'qemu-screen.ppm'
if any(char.isspace() for char in str(output)):
    parser.error('Use a work directory without whitespace')
os.umask(0o077)
def wait_for_prompt(monitor):
    response = b''
    while not response.rstrip().endswith(b'(qemu)'):
        chunk = monitor.recv(4096)
        if not chunk:
            raise RuntimeError('QEMU monitor closed before completing the screenshot')
        response += chunk


fd, temporary_name = tempfile.mkstemp(prefix='qemu-screen-', suffix='.ppm', dir=work)
os.close(fd)
temporary = Path(temporary_name)
try:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as monitor:
        monitor.settimeout(10)
        monitor.connect(str(work / 'qemu-monitor.sock'))
        wait_for_prompt(monitor)
        monitor.sendall(f'screendump {temporary}\n'.encode())
        wait_for_prompt(monitor)
    if temporary.stat().st_size == 0:
        raise SystemExit('QEMU did not create a screenshot')
    # Readers can copy the previous image while QEMU writes the next one.
    temporary.replace(output)
finally:
    temporary.unlink(missing_ok=True)
print(output)
