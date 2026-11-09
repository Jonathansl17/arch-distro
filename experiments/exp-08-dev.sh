#!/usr/bin/env bash
# Theme 8 experiment:
#   1. modules: inspect, load and unload the "dummy" network module
#   2. blacklist in effect (pcspkr, joydev)
#   3. GPU/NPU drivers (lspci -k, ad-info)
#   4. /proc/interrupts before/after intensive disk I/O
#   5. udev: monitor for USB_WAIT_SECS while you plug a USB stick
# Output: results/tema-08/<ts>/
set -euo pipefail
source "$(dirname "$0")/common.sh"
require lsmod modinfo modprobe udevadm ad-dev ad-info

PROBE_MODULE="dummy"
IO_FILE="/var/tmp/ad-io-test"
IO_MIB=1024
USB_WAIT_SECS=30

dir="$(results_dir tema-08)"
run_logged "$dir/1-modules.txt" bash -c 'lsmod | wc -l'
run_logged "$dir/1-modules.txt" modinfo "$PROBE_MODULE"
run_logged "$dir/1-modules.txt" sudo modprobe "$PROBE_MODULE"
run_logged "$dir/1-modules.txt" bash -c "lsmod | grep -w $PROBE_MODULE; ip -br link show type dummy"
run_logged "$dir/1-modules.txt" sudo modprobe -r "$PROBE_MODULE"
run_logged "$dir/1-modules.txt" bash -c "lsmod | grep -cw $PROBE_MODULE || true"

run_logged "$dir/2-blacklist.txt" cat /usr/lib/modprobe.d/ad-blacklist.conf
run_logged "$dir/2-blacklist.txt" bash -c 'modprobe --showconfig | grep -E "blacklist (pcspkr|joydev)"'
run_logged "$dir/2-blacklist.txt" bash -c 'lsmod | grep -E "^(pcspkr|joydev) " || echo "not loaded"'

run_logged "$dir/3-drivers.txt" lspci -k
run_logged "$dir/3-drivers.txt" ad-info

say "Disk I/O of ${IO_MIB} MiB with O_DIRECT, interrupts counted"
run_logged "$dir/4-interrupts.txt" ad-dev irqdiff dd if=/dev/zero of="$IO_FILE" \
    bs=1M count="$IO_MIB" oflag=direct status=none
rm -f "$IO_FILE"

say "Plug a USB stick now (watching for ${USB_WAIT_SECS}s)"
timeout "$USB_WAIT_SECS" udevadm monitor --udev --kernel --subsystem-match=block \
    > "$dir/5-udev-monitor.txt" || :
run_logged "$dir/5-udev.txt" sudo dmesg --since "-${USB_WAIT_SECS}s"
run_logged "$dir/5-udev.txt" ad-dev usb
ok "results in $dir"
