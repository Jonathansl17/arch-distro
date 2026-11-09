#!/usr/bin/env bash
# Theme 3 experiment: fio on the btrfs root vs an ext4 file system.
# The ext4 side is a loop image created inside a NOCOW file, so btrfs
# copy-on-write does not distort the ext4 numbers. Same disk for both.
# Loads: sequential 1 MiB read/write and random 4 KiB read/write, O_DIRECT.
# Output: results/tema-03/<ts>/fio.csv (+ raw terse lines)
set -euo pipefail
source "$(dirname "$0")/common.sh"
require fio mkfs.ext4 losetup

IMG_DIR="/var/tmp/ad-fio"
IMG_SIZE="4G"
FILE_SIZE="1G"
RUNTIME_SECS=30
IODEPTH=16
REPEATS=3
EXT4_MNT="/mnt/ad-ext4"
# name:rw:bs
JOBS=("seqread:read:1M" "seqwrite:write:1M" "randread:randread:4k" "randwrite:randwrite:4k")
# fio --minimal (terse v3) fields: 7/8 read KiB/s + IOPS, 48/49 write KiB/s + IOPS
TERSE_AWK='{ printf "%s,%s,%s,%s", $7, $8, $48, $49 }'

setup_ext4() {
    sudo mkdir -p "$IMG_DIR" "$EXT4_MNT"
    if ! mountpoint -q "$EXT4_MNT"; then
        sudo rm -f "$IMG_DIR/ext4.img"
        sudo touch "$IMG_DIR/ext4.img"
        sudo chattr +C "$IMG_DIR/ext4.img" 2>/dev/null || warn "chattr +C failed (not btrfs?)"
        sudo fallocate -l "$IMG_SIZE" "$IMG_DIR/ext4.img"
        sudo mkfs.ext4 -q -F "$IMG_DIR/ext4.img"
        sudo mount -o loop "$IMG_DIR/ext4.img" "$EXT4_MNT"
    fi
    sudo install -d -o "$USER" "$EXT4_MNT/fio" "$IMG_DIR/btrfs-fio"
}

cleanup() {
    sudo umount "$EXT4_MNT" 2>/dev/null || :
    sudo rm -rf "$IMG_DIR"
}

# run_job FS DIR JOB REPEAT CSV
run_job() {
    local fs="$1" target="$2" name rw bs line
    IFS=: read -r name rw bs <<< "$3"
    line="$(fio --minimal --name="$name" --directory="$target" --rw="$rw" \
        --bs="$bs" --size="$FILE_SIZE" --runtime="$RUNTIME_SECS" --time_based \
        --ioengine=io_uring --iodepth="$IODEPTH" --direct=1 --end_fsync=1 \
        --group_reporting)"
    echo "$line" >> "$5.raw"
    echo "$fs,$name,$4,$(awk -F';' "$TERSE_AWK" <<< "$line")" | tee -a "$5"
}

dir="$(results_dir tema-03)"
csv="$dir/fio.csv"
trap cleanup EXIT
setup_ext4
run_logged "$dir/setup.txt" findmnt -no SOURCE,FSTYPE,OPTIONS /
run_logged "$dir/setup.txt" findmnt -no SOURCE,FSTYPE,OPTIONS "$EXT4_MNT"
echo "fs,job,repeat,read_kib_s,read_iops,write_kib_s,write_iops" > "$csv"
for rep in $(seq 1 "$REPEATS"); do
    for job in "${JOBS[@]}"; do
        run_job btrfs "$IMG_DIR/btrfs-fio" "$job" "$rep" "$csv"
        run_job ext4 "$EXT4_MNT/fio" "$job" "$rep" "$csv"
    done
done
ok "results in $dir"
