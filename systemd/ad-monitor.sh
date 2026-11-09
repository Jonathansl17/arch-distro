#!/usr/bin/env bash
# ad-monitor.sh - body of ad-monitor.service (theme 4).
# Every INTERVAL_SECS writes one line to stdout (-> journal) with the kernel
# pressure stall information (PSI) and the load average.
#
# For the resource-limit experiment, /etc/arch-distro/monitor.env can set:
#   LOAD_WORKERS=N   spawn N busy loops inside this cgroup (tests CPUQuota=)
#   LOAD_MEM_MIB=M   hold M MiB of anonymous memory (tests MemoryMax=)
set -uo pipefail

INTERVAL_SECS="${INTERVAL_SECS:-10}"
LOAD_WORKERS="${LOAD_WORKERS:-0}"
LOAD_MEM_MIB="${LOAD_MEM_MIB:-0}"
PSI_DIR="/proc/pressure"
children=()

psi_avg10() {
    # "some avg10=0.12 avg60=..." -> 0.12
    awk -F'[ =]' '/^some/ {print $3}' "$PSI_DIR/$1"
}

start_load() {
    local i
    for ((i = 0; i < LOAD_WORKERS; i++)); do
        ( while :; do :; done ) &
        children+=("$!")
    done
    if (( LOAD_MEM_MIB > 0 )); then
        # tail must buffer the whole stream because it never sees a newline
        head -c "${LOAD_MEM_MIB}M" /dev/zero | tail > /dev/null &
        children+=("$!")
    fi
    echo "load: ${LOAD_WORKERS} cpu workers, ${LOAD_MEM_MIB} MiB memory"
}

shutdown() {
    echo "SIGTERM received, stopping ${#children[@]} helper(s)"
    (( ${#children[@]} )) && kill "${children[@]}" 2>/dev/null
    exit 0
}

trap shutdown TERM INT
start_load
while :; do
    read -r l1 l5 l15 _ < /proc/loadavg
    echo "psi cpu=$(psi_avg10 cpu) mem=$(psi_avg10 memory) io=$(psi_avg10 io)" \
         "load=$l1/$l5/$l15"
    sleep "$INTERVAL_SECS" &
    wait $!
done
