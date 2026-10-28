#!/bin/sh
set -u

BANNER_FIRST_LINE="GRACEOS 0.1 - dedicated to Andrew Tanenbaum and Linus Torvalds,"
BANNER_SECOND_LINE="who argued about this in 1992. They were both right."
POLL_INTERVAL_SECONDS=0.1
MAX_POLLS=100

serial_output=$(mktemp)
qemu-system-i386 -cpu 486 "$@" -display none -serial "file:$serial_output" -no-reboot &
qemu_process=$!
trap 'kill -KILL "$qemu_process" 2>/dev/null; rm -f "$serial_output"' EXIT

banner_printed() {
    grep -qF "$BANNER_FIRST_LINE" "$serial_output" && grep -qF "$BANNER_SECOND_LINE" "$serial_output"
}

poll=0
while [ "$poll" -lt "$MAX_POLLS" ]; do
    if banner_printed; then
        echo "boot test passed: qemu $*"
        exit 0
    fi
    if ! kill -0 "$qemu_process" 2>/dev/null; then
        break
    fi
    sleep "$POLL_INTERVAL_SECONDS"
    poll=$((poll + 1))
done

echo "boot test failed: no banner on COM1: qemu $*"
echo "serial output was:"
cat "$serial_output"
exit 1
