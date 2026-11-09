#!/usr/bin/env bash
# ad-usb-event.sh DEVNAME - started by ad-usb-event@.service when the udev
# rule 90-ad-usb-storage.rules sees a USB disk. Appends what the kernel knows
# about the device (sysfs) to the usb events log.
set -euo pipefail

dev="${1:?usage: ad-usb-event.sh DEVNAME}"
sys="/sys/class/block/$dev"
log="${LOGS_DIRECTORY:?run me from ad-usb-event@.service}/usb-events.log"
SECTOR_BYTES=512
BYTES_PER_MIB=$((1024 * 1024))

[[ -d "$sys" ]] || { echo "device $dev vanished" >&2; exit 1; }
size_mib=$(( $(cat "$sys/size") * SECTOR_BYTES / BYTES_PER_MIB ))
vendor="$(cat "$sys/device/vendor" 2>/dev/null || echo '?')"
model="$(cat "$sys/device/model" 2>/dev/null || echo '?')"
driver="$(basename "$(readlink -f "$sys/device/driver" 2>/dev/null || echo none)")"

printf '%s add /dev/%s vendor=%s model=%s size=%sMiB driver=%s\n' \
    "$(date -Is)" "$dev" "${vendor// /}" "${model// /}" "$size_mib" "$driver" \
    | tee -a "$log"
