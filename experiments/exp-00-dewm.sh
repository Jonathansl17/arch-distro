#!/usr/bin/env bash
# DE/WM comparison (Capa 1): idle memory and process count of the running
# graphical session. Run it in each session after 2 minutes idle, nothing
# open but one terminal:
#   bspwm session:  ./exp-00-dewm.sh bspwm
#   alternative:    ./exp-00-dewm.sh xfce    (see docs/de-wm.md to start it)
# Output: results/dewm/<label>-*.txt and a line in results/dewm/summary.csv
set -euo pipefail
source "$(dirname "$0")/common.sh"
require free ps

# pss_kib PID -> proportional set size of PID from the kernel (0 if it exited).
pss_kib() {
    awk '/^Pss:/ {print $2; found=1} END {if (!found) print 0}' \
        "/proc/$1/smaps_rollup" 2>/dev/null || echo 0
}

# pss_table -> "pid pss_kib name" for every process of $USER, biggest first.
pss_table() {
    local pid
    for pid in $(pgrep -u "$USER"); do
        printf '%s %s %s\n' "$pid" "$(pss_kib "$pid")" "$(ps -o comm= -p "$pid")"
    done | sort -k2,2nr
}

SAMPLES=5
SAMPLE_GAP_SECS=10
TOP_PROCS=15
out="$EXP_REPO/results/dewm"
label="${1:?usage: $0 LABEL}"
mkdir -p "$out"
[[ -f "$out/summary.csv" ]] || echo "label,sample,used_mib,user_procs,user_pss_kib" > "$out/summary.csv"

for i in $(seq 1 "$SAMPLES"); do
    used="$(free -m | awk '/^Mem:/ {print $3}')"
    procs="$(ps -u "$USER" --no-headers | wc -l)"
    pss="$(pss_table | awk '{sum += $2} END {print sum + 0}')"
    echo "$label,$i,$used,$procs,$pss" | tee -a "$out/summary.csv"
    sleep "$SAMPLE_GAP_SECS"
done
pss_table | head -n "$TOP_PROCS" > "$out/$label-top-pss.txt"
ps -u "$USER" -o pid,rss,comm --sort=-rss > "$out/$label-ps.txt"
ok "appended to $out/summary.csv"
