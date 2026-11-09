#!/usr/bin/env bash
# arch-distro bootstrap. Run as your normal user (with sudo) on a manual Arch
# base install (see docs/instalacion.md). Idempotent: every step checks the
# current state first, so running it twice changes nothing the second time.
#
#   ./install.sh               base (arch-config) + every arch-distro layer
#   ./install.sh --skip-base   only the arch-distro layers
#   ./install.sh --only STEP   one step: base packages memory btrfs tools
#                              security services
#
# A full log is written to ~/.local/state/arch-distro/install-<date>.log
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_DIR

# shellcheck source=config/settings.sh
source "$REPO_DIR/config/settings.sh"
for lib in log fsutil step-base step-packages step-memory step-btrfs \
           step-tools step-security step-services; do
    # shellcheck source=/dev/null
    source "$REPO_DIR/lib/$lib.sh"
done

ALL_STEPS=(base packages memory btrfs tools security services)

usage() { sed -n '2,11p' "$0"; exit 2; }

preflight() {
    (( EUID != 0 )) || die "run as your normal user, not root (sudo is used per step)"
    command -v pacman >/dev/null || die "pacman not found: this is not Arch Linux"
    [[ -d /sys/firmware/efi ]] || warn "not booted in UEFI mode (the project requires UEFI)"
    sudo -v || die "sudo is required"
}

run_steps() {
    local step
    for step in "$@"; do
        say "===== step: $step ====="
        "step_$step"
    done
}

main() {
    local steps=("${ALL_STEPS[@]}")
    case "${1:-}" in
        "")          ;;
        --skip-base) steps=("${ALL_STEPS[@]:1}") ;;
        --only)      [[ " ${ALL_STEPS[*]} " == *" ${2:-?} "* ]] || usage
                     steps=("$2") ;;
        *)           usage ;;
    esac
    preflight
    mkdir -p "$LOG_DIR"
    local log
    log="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
    say "Logging to $log"
    run_steps "${steps[@]}" 2>&1 | tee "$log"
    ok "arch-distro ready. Reboot once so zram, the blacklist and every unit start clean."
}

main "$@"
