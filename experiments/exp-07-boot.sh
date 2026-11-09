#!/usr/bin/env bash
# Theme 7 experiment: boot-time snapshot. Run once per boot, with a label:
#   ./exp-07-boot.sh before     (reboot, run again, 3 boots per label)
#   apply the optimization (see docs/tema-07-arranque.md)
#   ./exp-07-boot.sh after      (3 boots)
#   ./exp-07-boot.sh summary    -> table of every recorded boot
# Output: results/tema-07/boots.csv + per-boot blame/critical-chain/plot
set -euo pipefail
source "$(dirname "$0")/common.sh"
require systemd-analyze

OUT="$EXP_REPO/results/tema-07"
CSV="$OUT/boots.csv"
BLAME_LINES=15

# "Startup finished in 3.1s (firmware) + 2.0s (loader) + ..." -> csv fields
stage_seconds() {
    systemd-analyze time | head -n1 | awk '
        function secs(v) { if (v ~ /ms$/) return v / 1000; if (v ~ /min$/) return v * 60; return v + 0 }
        { for (i = 1; i <= NF; i++) if ($i ~ /^\(/) { gsub(/[()]/, "", $i); t[$i] = secs($(i - 1)) } }
        END { printf "%.3f,%.3f,%.3f,%.3f,%.3f", t["firmware"], t["loader"],
              t["kernel"], t["initrd"], t["userspace"] }'
}

record() {
    local label="$1" boot ts
    boot="$(journalctl --list-boots --no-pager | awk '$1 == 0 {print $2}')"
    ts="$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$OUT/$label"
    [[ -f "$CSV" ]] || echo "label,boot_id,firmware,loader,kernel,initrd,userspace" > "$CSV"
    if grep -q "$boot" "$CSV"; then
        die "boot $boot already recorded; reboot first"
    fi
    echo "$label,$boot,$(stage_seconds)" | tee -a "$CSV"
    systemd-analyze time > "$OUT/$label/$ts-time.txt"
    systemd-analyze blame | head -n "$BLAME_LINES" > "$OUT/$label/$ts-blame.txt"
    systemd-analyze critical-chain > "$OUT/$label/$ts-chain.txt"
    systemd-analyze plot > "$OUT/$label/$ts-plot.svg"
    cat /proc/cmdline > "$OUT/$label/$ts-cmdline.txt"
}

summary() {
    awk -F, 'NR > 1 { n[$1]++; for (i = 3; i <= 7; i++) s[$1, i] += $i }
        END { printf "%-8s %3s %9s %8s %8s %8s %9s\n", "label", "n", "firmware",
                     "loader", "kernel", "initrd", "userspace"
              for (l in n) { printf "%-8s %3d", l, n[l]
                  for (i = 3; i <= 7; i++) printf " %8.3f", s[l, i] / n[l]
                  printf "\n" } }' "$CSV"
}

case "${1:-}" in
    summary) summary ;;
    "")      die "usage: $0 LABEL|summary" ;;
    *)       record "$1" ;;
esac
