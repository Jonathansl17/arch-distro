#!/usr/bin/env bash
# ad-pacnew-check.sh - run by ad-pacnew.hook. stdin = package names of the
# transaction (NeedsTargets). Lists pending .pacnew/.pacsave files and logs.
set -euo pipefail

LOG_DIR="/var/log/arch-distro"
LOG="$LOG_DIR/pacman-hook.log"
SEARCH_ROOT="/etc"

mapfile -t targets
pending="$(find "$SEARCH_ROOT" -xdev \( -name '*.pacnew' -o -name '*.pacsave' \) \
    2>/dev/null || true)"

mkdir -p "$LOG_DIR"
{
    echo "$(date -Is) transaction: ${#targets[@]} package(s): ${targets[*]}"
    echo "$(date -Is) pending: ${pending:-none}" | tr '\n' ' '
    echo
} >> "$LOG"

if [[ -n "$pending" ]]; then
    echo "pending config merges (review with pacdiff):"
    echo "$pending" | sed 's/^/  /'
else
    echo "no .pacnew/.pacsave files pending"
fi
