#!/usr/bin/env bash
# Runs every unattended experiment once, in order, copies the output to
# evidence/<member>/ and ends with a one-screen summary to screenshot.
# About 30 minutes.
#   experiments/run-all.sh [NAME]   (default: $USER)
# Not included (need a human or a reboot): exp-07 after more boots,
# exp-00-dewm (needs a second desktop session), exp-09-nmap-remote (runs
# from another machine). exp-08 waits 30 s for a USB stick and goes on.
# RUN_ALL_UPLOAD=1 (set by run-and-send.sh) uploads after every experiment.
set -euo pipefail
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/upload.sh"

member="${1:-$USER}"   # optional: defaults to the login name
SUDO_REFRESH_SECS=60
# A hung experiment is stopped (its whole process group) and the run goes on.
EXP_TIMEOUT_SECS=1200
EXP_KILL_AFTER_SECS=10
EXPERIMENTS=(exp-00-capa1 exp-01-sched exp-02-mem exp-03-fs exp-03-rollback
             exp-04-svc exp-05-ipc exp-06-pkg exp-08-dev exp-09-sec)

sudo -v || die "sudo is required"
# Keep the sudo timestamp fresh so a long fio run does not stop at a prompt.
( while sudo -n true; do sleep "$SUDO_REFRESH_SECS"; done ) &
keepalive=$!
trap 'kill "$keepalive" 2>/dev/null' EXIT

dest="$EXP_REPO/evidence/$member"
exp_logs="$dest/run-logs"
mkdir -p "$exp_logs"

# collect LABEL -> refresh evidence/<member>/ and, if asked, upload it.
collect() {
    cp -a "$EXP_REPO/results/." "$dest/" 2>/dev/null || :
    cp -a "$LOG_DIR"/install-*.log "$dest/" 2>/dev/null || :
    [[ "${RUN_ALL_UPLOAD:-0}" == 1 ]] || return 0
    upload_evidence "$member" "$1" || :
}

failed=()
for exp in "${EXPERIMENTS[@]}"; do
    say "===== $exp ====="
    # Theme 3 compares a btrfs root against ext4: nothing to measure on ext4.
    if [[ "$exp" == exp-03-* && "$(findmnt -no FSTYPE /)" != "btrfs" ]]; then
        warn "root is not btrfs: skipping $exp (theme 3 not applicable)"
        continue
    fi
    args=()
    [[ "$exp" == exp-00-capa1 ]] && args=("$member")
    # Each run is also kept in run-logs/ so a failure survives the final clear.
    if ! timeout --kill-after="$EXP_KILL_AFTER_SECS" "$EXP_TIMEOUT_SECS" \
            "$EXP_REPO/experiments/$exp.sh" "${args[@]}" 2>&1 | tee "$exp_logs/$exp.log"; then
        warn "$exp failed or timed out, continuing (see $exp_logs/$exp.log)"
        failed+=("$exp")
    fi
    collect "$exp"
done
say "===== exp-07-boot (this boot) ====="
"$EXP_REPO/experiments/exp-07-boot.sh" before 2>&1 | tee "$exp_logs/exp-07-boot.log" \
    || failed+=("exp-07-boot")

collect exp-07-boot
clear
"$EXP_REPO/experiments/summary.sh" "$member" | tee "$dest/summary.txt"
(( ${#failed[@]} == 0 )) || warn "failed: ${failed[*]} (logs: $exp_logs)"
