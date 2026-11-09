#!/usr/bin/env bash
# One-screen diagnosis of why run-all experiments fail: which install steps
# ran, which commands the experiments need are missing, and the state of the
# theme 9 users, ACL and sudoers. Read-only except for `sudo -v`.
#   experiments/diagnose.sh
set -uo pipefail
source "$(dirname "$0")/common.sh"

EXP_COMMANDS=(ad-ps ad-mem ad-ipc ad-info ad-svc ad-pkg ad-dev ad-snap
              taskset chrt stress-ng vmstat fio mkfs.ext4 losetup strace
              systemd-cgls pactree lsmod udevadm getfacl nft ss snapper)
SUDOERS_FILE="/etc/sudoers.d/arch-distro"
LOG_LINES=20

section() { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

show_install_logs() {
    section "install.sh steps and errors (last $LOG_LINES lines)"
    local logs=("$LOG_DIR"/install-*.log)
    [[ -e "${logs[0]}" ]] || { warn "no install logs in $LOG_DIR"; return; }
    grep -hE "===== step|\[xx\]|ERROR|error:|failed" "${logs[@]}" | tail -n "$LOG_LINES"
}

show_missing_commands() {
    section "commands the experiments need"
    local cmd missing=()
    for cmd in "${EXP_COMMANDS[@]}"; do
        command -v "$cmd" >/dev/null || missing+=("$cmd")
    done
    if (( ${#missing[@]} )); then
        warn "missing: ${missing[*]}"
    else
        ok "all ${#EXP_COMMANDS[@]} present"
    fi
    pacman -Q "$TOOLS_PKG_NAME" || warn "$TOOLS_PKG_NAME not installed"
}

show_security_state() {
    section "theme 9 state"
    id "$OPERATOR_USER" || true
    id "$READONLY_USER" || true
    getfacl -p "$SHARED_DIR" || true
    sudo test -f "$SUDOERS_FILE" && ok "$SUDOERS_FILE present" \
        || warn "$SUDOERS_FILE missing"
    systemctl is-enabled nftables sshd ad-monitor.service ad-report.timer || true
}

sudo -v || die "sudo is required"
show_install_logs
show_missing_commands
show_security_state
