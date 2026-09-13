#!/bin/bash
# Run in Rescue as root with a reviewed install.env loaded and an existing INSTALL_ISO.
# Every invocation uses CHECK_ONLY=1; no QEMU process is launched.
set -euo pipefail
installer="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install-qemu.sh"
export CHECK_ONLY=1
: "${TARGET_DISK_1:?Load the reviewed install.env first}"
: "${EXPECTED_SERIAL_1:?Load the reviewed install.env first}"
: "${EXPECTED_SERIAL_2:?Load the reviewed install.env first}"
: "${FIRMWARE_MODE:?Load the reviewed install.env first}"
approved="${EXPECTED_SERIAL_1}+${EXPECTED_SERIAL_2}"

expect_refusal() {
    local label="$1" expected="$2" output
    shift 2
    if output=$(env ERASE_CONFIRMED="$approved" "$@" bash "$installer" 2>&1); then
        echo "FAIL: $label was accepted" >&2
        exit 1
    fi
    if [[ "$output" != *"$expected"* ]]; then
        printf 'FAIL: %s returned an unexpected refusal: %s\n' "$label" "$output" >&2
        exit 1
    fi
    echo "PASS: $label refused"
}

expect_refusal 'missing erase flag' 'Set ERASE_CONFIRMED' ERASE_CONFIRMED=
expect_refusal 'legacy YES erase flag' 'Set ERASE_CONFIRMED' ERASE_CONFIRMED=YES
expect_refusal 'erase flag for other serials' 'Set ERASE_CONFIRMED' ERASE_CONFIRMED=other-serial-1+other-serial-2
expect_refusal 'missing firmware mode' 'Legacy BIOS is mandatory' FIRMWARE_MODE=
expect_refusal 'UEFI mode' 'Legacy BIOS is mandatory' FIRMWARE_MODE=uefi
expect_refusal 'invalid firmware mode' 'Legacy BIOS is mandatory' FIRMWARE_MODE=automatic
expect_refusal 'duplicate disks' 'Target disks must be different' TARGET_DISK_2="$TARGET_DISK_1"
expect_refusal 'wrong serial' 'Serial mismatch' \
    EXPECTED_SERIAL_1=deliberately-wrong-serial ERASE_CONFIRMED="deliberately-wrong-serial+${EXPECTED_SERIAL_2}"
ERASE_CONFIRMED="$approved" bash "$installer"
echo 'PASS: approved configuration accepted in CHECK_ONLY mode'
