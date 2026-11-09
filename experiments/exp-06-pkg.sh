#!/usr/bin/env bash
# Theme 6 experiment: the own package, the own hook in a real transaction,
# and a dependency tree.
# Output: results/tema-06/<ts>/
set -euo pipefail
source "$(dirname "$0")/common.sh"
require pacman pactree ad-pkg

# Small package reinstalled to produce a real transaction that fires hooks.
PROBE_PKG="pacman-contrib"
TREE_PKG="openssh"
HOOK_LOG="/var/log/arch-distro/pacman-hook.log"

dir="$(results_dir tema-06)"
run_logged "$dir/1-package.txt" pacman -Qi "$TOOLS_PKG_NAME"
run_logged "$dir/1-package.txt" pacman -Ql "$TOOLS_PKG_NAME"
run_logged "$dir/1-package.txt" pacman -Qkk "$TOOLS_PKG_NAME"
run_logged "$dir/2-db.txt" ad-pkg db
run_logged "$dir/2-db.txt" ad-pkg hooks
run_logged "$dir/2-db.txt" ls "/var/lib/pacman/local/$(pacman -Q "$TOOLS_PKG_NAME" | tr ' ' '-')"
say "Real transaction (reinstall $PROBE_PKG) to fire the hook"
run_logged "$dir/3-transaction.txt" sudo pacman -S --noconfirm "$PROBE_PKG"
run_logged "$dir/3-transaction.txt" sudo tail -n 4 "$HOOK_LOG"
run_logged "$dir/4-deps.txt" ad-pkg deps "$TREE_PKG"
run_logged "$dir/4-deps.txt" pacman -Qi "$TREE_PKG"
ok "results in $dir"
