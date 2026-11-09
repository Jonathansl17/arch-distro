#!/usr/bin/env bash
# Theme 4 experiment on ad-monitor.service:
#   1. cgroup placement (systemd-cgls) and unit properties
#   2. CPUQuota=20% under load: 2 busy workers inside the unit, measure the
#      unit's CPU use from cpu.stat over a window (must stay <= 20% of 1 CPU)
#   3. MemoryMax=64M: a helper asks for 128 MiB, the cgroup OOM-kills it
#   4. Restart=on-failure: SIGKILL the main process, systemd restarts it
# Output: results/tema-04/<ts>/
set -euo pipefail
source "$(dirname "$0")/common.sh"
require ad-svc systemd-cgls

UNIT="ad-monitor.service"
WINDOW_SECS=20
SETTLE_SECS=3
CPU_WORKERS=2
MEM_MIB=128
USEC_PER_SEC=1000000
PERCENT=100

set_env() {
    printf 'INTERVAL_SECS=10\nLOAD_WORKERS=%s\nLOAD_MEM_MIB=%s\n' "$1" "$2" \
        | sudo tee "$MONITOR_ENV_FILE" >/dev/null
    restart_unit
    sleep "$SETTLE_SECS"
}

# restart_unit -> clean restart. The memory step makes systemd restart the unit
# after every OOM kill, which can exhaust StartLimitBurst; reset-failed clears
# that counter so the next step does not start from start-limit-hit.
restart_unit() {
    sudo systemctl reset-failed "$UNIT"
    sudo systemctl restart "$UNIT"
}

cpu_usec() {
    awk '/^usage_usec/ {print $2}' \
        "/sys/fs/cgroup$(systemctl show -P ControlGroup "$UNIT")/cpu.stat"
}

measure_quota() {
    local a b
    a="$(cpu_usec)"
    sleep "$WINDOW_SECS"
    b="$(cpu_usec)"
    awk -v d="$((b - a))" -v w="$WINDOW_SECS" -v u="$USEC_PER_SEC" -v p="$PERCENT" \
        'BEGIN { printf "unit CPU over %ds: %.1f%% of one CPU (quota 20%%)\n", w, d / (w * u) * p }'
}

# count_memcg_kills EPOCH -> cgroup OOM kills inside UNIT since EPOCH
count_memcg_kills() {
    local n
    n="$(journalctl -k --no-pager -q --since "@$1" \
        | grep -c "Memory cgroup out of memory" || true)"
    echo "cgroup OOM kills in $UNIT during this step: $n"
}

dir="$(results_dir tema-04)"
original="$(mktemp)"
sudo cp "$MONITOR_ENV_FILE" "$original"
trap 'sudo cp "$original" "$MONITOR_ENV_FILE"; restart_unit; rm -f "$original"' EXIT

run_logged "$dir/1-cgroup.txt" systemctl show "$UNIT" -p CPUQuotaPerSecUSec -p MemoryMax \
    -p Restart -p RestartUSec -p After -p Wants
run_logged "$dir/1-cgroup.txt" systemd-cgls --no-pager -u "$UNIT"
run_logged "$dir/1-cgroup.txt" systemctl list-timers ad-report.timer --no-pager

say "CPU quota under load ($CPU_WORKERS busy workers)"
set_env "$CPU_WORKERS" 0
run_logged "$dir/2-quota.txt" measure_quota
run_logged "$dir/2-quota.txt" ad-svc "$UNIT"

say "Memory limit ($MEM_MIB MiB requested, MemoryMax=64M)"
mem_since="$(date +%s)"
set_env 0 "$MEM_MIB"
sleep "$SETTLE_SECS"
run_logged "$dir/3-memory.txt" ad-svc "$UNIT"
# memory.events resets every time systemd recreates the cgroup on restart, so
# the kills of this step are counted from the kernel log instead.
run_logged "$dir/3-memory.txt" count_memcg_kills "$mem_since"

say "Restart after a provoked failure"
set_env 0 0
run_logged "$dir/4-restart.txt" ad-svc crash "$UNIT"
ok "results in $dir"
