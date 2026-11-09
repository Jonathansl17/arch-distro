#!/usr/bin/env bash
# Theme 1 experiment: CPU share of CPU-bound processes pinned to one core.
#   Part A: two SCHED_OTHER loops with different nice values. EEVDF splits the
#           core in proportion to their load weights (sched_prio_to_weight).
#   Part B: one SCHED_FIFO loop against one SCHED_OTHER loop (needs sudo).
# Output: results/tema-01/<ts>/shares.csv + raw ad-ps samples.
set -euo pipefail
source "$(dirname "$0")/common.sh"
require taskset chrt ad-ps

CORE=0
WINDOW_MS=10000
NICE_PAIRS=("0 0" "0 5" "0 10" "0 19" "-5 5")
RT_PRIORITY=10
# Kernel table kernel/sched/core.c sched_prio_to_weight[], index = nice + 20.
WEIGHTS=(88761 71755 56483 46273 36291 29154 23254 18705 14949 11916
         9548 7620 6100 4904 3906 3121 2501 1991 1586 1277
         1024 820 655 526 423 335 272 215 172 137
         110 87 70 56 45 36 29 23 18 15)
NICE_OFFSET=20

weight() { echo "${WEIGHTS[$(($1 + NICE_OFFSET))]}"; }

# spin NICE -> starts a busy loop on CORE with that nice value, prints its PID.
# Output is detached so $(spin) does not wait for the loop to finish.
spin() {
    taskset -c "$CORE" bash -c 'while :; do :; done' >/dev/null 2>&1 &
    local pid=$!
    if (( $1 < 0 )); then
        sudo renice -n "$1" -p "$pid" >/dev/null   # lowering nice needs root
    else
        renice -n "$1" -p "$pid" >/dev/null
    fi
    echo "$pid"
}

# measure_pair PID1 PID2 RAW -> "cpu1 cpu2" (CPU% column of ad-ps).
measure_pair() {
    local p1="$1" p2="$2" raw="$3"
    ad-ps -p "$p1" -p "$p2" -i "$WINDOW_MS" -s pid -n 0 | tee -a "$raw" \
        | awk -v a="$p1" -v b="$p2" '$1 == a {x = $8} $1 == b {y = $8} END {print x, y}'
}

part_a() {
    local dir="$1" pair n1 n2 p1 p2 c1 c2 w1 w2
    echo "nice1,nice2,cpu1,cpu2,measured_share1,expected_share1" > "$dir/shares.csv"
    for pair in "${NICE_PAIRS[@]}"; do
        read -r n1 n2 <<< "$pair"
        p1="$(spin "$n1")"
        p2="$(spin "$n2")"
        read -r c1 c2 < <(measure_pair "$p1" "$p2" "$dir/ad-ps-raw.txt")
        kill "$p1" "$p2"
        w1="$(weight "$n1")"; w2="$(weight "$n2")"
        awk -v n1="$n1" -v n2="$n2" -v c1="$c1" -v c2="$c2" -v w1="$w1" -v w2="$w2" \
            'BEGIN { printf "%d,%d,%.1f,%.1f,%.3f,%.3f\n", n1, n2, c1, c2,
                     c1 / (c1 + c2), w1 / (w1 + w2) }' | tee -a "$dir/shares.csv"
    done
}

part_b() {
    local dir="$1" p_rt p_fair
    run_logged "$dir/rt.txt" cat /proc/sys/kernel/sched_rt_runtime_us /proc/sys/kernel/sched_rt_period_us
    p_rt="$(spin 0)"
    p_fair="$(spin 0)"
    run_logged "$dir/rt.txt" sudo chrt -f -p "$RT_PRIORITY" "$p_rt"
    run_logged "$dir/rt.txt" ad-ps -p "$p_rt" -p "$p_fair" -i "$WINDOW_MS" -s pid -n 0
    kill "$p_rt" "$p_fair"
}

dir="$(results_dir tema-01)"
say "Kernel scheduler: $(ad-info | grep -m1 Scheduler)"
say "Part A: nice pairs on core $CORE (${WINDOW_MS} ms each)"
part_a "$dir"
say "Part B: SCHED_FIFO vs SCHED_OTHER on core $CORE"
part_b "$dir"
ok "results in $dir"
