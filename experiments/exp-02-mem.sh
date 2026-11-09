#!/usr/bin/env bash
# Theme 2 experiment: memory pressure with and without zram.
# Each run: stress-ng --vm allocates more than the free RAM while vmstat and
# ad-mem --csv sample once per second. Run "with" zram, then "without"
# (zram0 is swapped off for that run and restored afterwards).
# Output: results/tema-02/<ts>/{with,without}-{vmstat,admem,stress}.txt
set -euo pipefail
source "$(dirname "$0")/common.sh"
require stress-ng vmstat ad-mem

DURATION_SECS=60
SAMPLE_SECS=1
VM_WORKERS=2
VM_BYTES_PER_WORKER="65%"   # 2 x 65% of available RAM = 130%: forces swapping
ZRAM_DEV="/dev/zram0"

run_once() {
    local dir="$1" label="$2"
    say "Run '$label': $(swapon --show=NAME,PRIO --noheadings | tr '\n' ' ')"
    swapon --show > "$dir/$label-swaps.txt"
    vmstat -w "$SAMPLE_SECS" "$((DURATION_SECS + 5))" > "$dir/$label-vmstat.txt" &
    local vm=$!
    ad-mem --csv -i "$((SAMPLE_SECS * 1000))" -c "$((DURATION_SECS + 5))" \
        > "$dir/$label-admem.csv" &
    local am=$!
    run_logged "$dir/$label-stress.txt" stress-ng --vm "$VM_WORKERS" \
        --vm-bytes "$VM_BYTES_PER_WORKER" --vm-keep --timeout "${DURATION_SECS}s" \
        --metrics-brief
    wait "$vm" "$am"
    sudo dmesg | grep -iE 'out of memory|oom-kill|killed process' \
        > "$dir/$label-oom.txt" || echo "no OOM kill" > "$dir/$label-oom.txt"
}

# summarize LABEL DIR -> total swap-in/out pages (vmstat si/so columns 7/8).
summarize() {
    awk -v l="$1" 'NR > 2 { si += $7; so += $8 }
        END { printf "%s: sum si=%d so=%d (KiB/s samples)\n", l, si, so }' \
        "$2/$1-vmstat.txt"
}

dir="$(results_dir tema-02)"
run_logged "$dir/config.txt" cat /etc/systemd/zram-generator.conf
run_logged "$dir/config.txt" sysctl vm.swappiness vm.page-cluster
run_once "$dir" with
say "Disabling $ZRAM_DEV for the comparison run"
sudo swapoff "$ZRAM_DEV"
trap 'sudo systemctl start dev-zram0.swap' EXIT   # swapon again with prio 100
run_once "$dir" without
summarize with "$dir" | tee "$dir/summary.txt"
summarize without "$dir" | tee -a "$dir/summary.txt"
ok "results in $dir"
