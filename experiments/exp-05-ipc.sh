#!/usr/bin/env bash
# Theme 5 experiment on ad-ipc:
#   1. strace -f of a normal run: fork/clone, pipe, shm, futex, kill, wait4
#   2. race: REPEATS runs with the mutex vs REPEATS runs with --unsafe
#   3. SIGTERM mid-run: orderly shutdown, zero zombies, /dev/shm cleaned
# Output: results/tema-05/<ts>/
set -euo pipefail
source "$(dirname "$0")/common.sh"
require ad-ipc strace

INPUT_DIR="/usr/share/doc"
CONSUMERS=4
REPEATS=5
SLOW_MS=40
TERM_AFTER_SECS=2
SYSCALLS="clone,clone3,fork,vfork,pipe,pipe2,openat,ftruncate,mmap,munmap,unlink,futex,kill,wait4,rt_sigaction,exit_group"

dir="$(results_dir tema-05)"

say "strace -f of one run"
strace -f -tt -e trace="$SYSCALLS" -o "$dir/1-strace.txt" \
    ad-ipc -w "$CONSUMERS" "$INPUT_DIR" | tee "$dir/1-run.txt"
grep -E 'clone|pipe|shm|ftruncate|kill|wait4|exit_group' "$dir/1-strace.txt" \
    | grep -v 'resumed' | head -n 60 > "$dir/1-strace-key.txt"

say "Race condition: safe vs --unsafe ($REPEATS runs each)"
for mode in safe unsafe; do
    flag=()
    [[ "$mode" == unsafe ]] && flag=(--unsafe)
    for i in $(seq 1 "$REPEATS"); do
        rc=0
        ad-ipc -w "$CONSUMERS" "${flag[@]}" "$INPUT_DIR" >> "$dir/2-$mode.txt" || rc=$?
        echo "run $i exit=$rc" >> "$dir/2-$mode.txt"
    done
done
tail -n 4 "$dir/2-safe.txt" "$dir/2-unsafe.txt"

say "SIGTERM after ${TERM_AFTER_SECS}s"
ad-ipc -w "$CONSUMERS" -s "$SLOW_MS" "$INPUT_DIR" > "$dir/3-sigterm.txt" &
parent=$!
sleep "$TERM_AFTER_SECS"
run_logged "$dir/3-sigterm.txt" ps -o pid,ppid,stat,comm --ppid "$parent"
kill -TERM "$parent"
rc=0
wait "$parent" || rc=$?
echo "ad-ipc exit=$rc (130 = terminated by SIGTERM)" >> "$dir/3-sigterm.txt"
echo "zombies=$(ps -eo stat= | grep -c '^Z' || :)" >> "$dir/3-sigterm.txt"
echo "shm_left=$(find /dev/shm -name 'ad-ipc-*' | wc -l)" >> "$dir/3-sigterm.txt"
ok "results in $dir"
