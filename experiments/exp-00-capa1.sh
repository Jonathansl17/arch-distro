#!/usr/bin/env bash
# Capa 1 evidence: what the statement asks each member to show about the
# manual install. Run once per member after the first boot:
#   ./exp-00-capa1.sh [NAME]   (default: $USER)
# Output: logs/<member>/capa1-evidence.txt (versioned, unlike results/)
set -euo pipefail
source "$(dirname "$0")/common.sh"

member="${1:-$USER}"   # optional: defaults to the login name
out_dir="$EXP_REPO/logs/$member"
out="$out_dir/capa1-evidence.txt"
mkdir -p "$out_dir"
: > "$out"
run_logged "$out" uname -a
run_logged "$out" cat /sys/firmware/efi/fw_platform_size
run_logged "$out" lsblk -f
run_logged "$out" cat /etc/fstab
run_logged "$out" sudo btrfs subvolume list /
run_logged "$out" sudo bootctl status
run_logged "$out" efibootmgr -v
run_logged "$out" journalctl --list-boots --no-pager
run_logged "$out" grep -E '^(HOOKS|MODULES)=' /etc/mkinitcpio.conf
run_logged "$out" systemctl --version
ok "evidence written to $out"
