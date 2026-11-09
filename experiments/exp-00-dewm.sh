#!/usr/bin/env bash
# DE/WM comparison (Capa 1): idle memory and process count of the running
# graphical session. Run it in each session after 2 minutes idle, nothing
# open but one terminal:
#   bspwm session:  ./exp-00-dewm.sh bspwm
#   alternative:    ./exp-00-dewm.sh xfce    (see docs/de-wm.md to start it)
# Output: results/dewm/<label>-*.txt and a line in results/dewm/summary.csv
set -euo pipefail
source "$(dirname "$0")/common.sh"
require smem free

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
    pss="$(smem -u -H -c 'user pss' | awk -v u="$USER" '$1 == u {print $2}')"
    echo "$label,$i,$used,$procs,$pss" | tee -a "$out/summary.csv"
    sleep "$SAMPLE_GAP_SECS"
done
smem -r -k -c 'pid name pss rss' -U "$USER" | head -n "$TOP_PROCS" > "$out/$label-top-pss.txt"
ps -u "$USER" -o pid,rss,comm --sort=-rss > "$out/$label-ps.txt"
ok "appended to $out/summary.csv"
