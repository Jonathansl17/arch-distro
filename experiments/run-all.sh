#!/usr/bin/env bash
# Runs every unattended experiment once, in order, copies the output to
# evidence/<member>/ and ends with a one-screen summary to screenshot.
# About 30 minutes.
#   experiments/run-all.sh jonathan
# Not included (need a human or a reboot): exp-07 after more boots,
# exp-00-dewm (needs a second desktop session), exp-09-nmap-remote (runs
# from another machine). exp-08 waits 30 s for a USB stick and goes on.
set -euo pipefail
source "$(dirname "$0")/common.sh"

member="${1:?usage: $0 MEMBER_NAME}"
SUDO_REFRESH_SECS=60
EXPERIMENTS=(exp-00-capa1 exp-01-sched exp-02-mem exp-03-fs exp-03-rollback
             exp-04-svc exp-05-ipc exp-06-pkg exp-08-dev exp-09-sec)

sudo -v || die "sudo is required"
# Keep the sudo timestamp fresh so a long fio run does not stop at a prompt.
( while sudo -n true; do sleep "$SUDO_REFRESH_SECS"; done ) &
keepalive=$!
trap 'kill "$keepalive" 2>/dev/null' EXIT

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
    if ! "$EXP_REPO/experiments/$exp.sh" "${args[@]}"; then
        warn "$exp failed, continuing"
        failed+=("$exp")
    fi
done
say "===== exp-07-boot (this boot) ====="
"$EXP_REPO/experiments/exp-07-boot.sh" before || failed+=("exp-07-boot")

dest="$EXP_REPO/evidence/$member"
mkdir -p "$dest"
cp -a "$EXP_REPO/results/." "$dest/"
cp -a "$LOG_DIR"/install-*.log "$dest/" 2>/dev/null || warn "no install logs in $LOG_DIR"
clear
"$EXP_REPO/experiments/summary.sh" "$member" | tee "$dest/summary.txt"
(( ${#failed[@]} == 0 )) || warn "failed: ${failed[*]}"
