#!/usr/bin/env bash
# Theme 3 live demo: snapshot, destructive change, diff, rollback.
# Works on a dedicated directory under /etc so it never touches real config.
set -euo pipefail
source "$(dirname "$0")/common.sh"
require ad-snap

DEMO_DIR="/etc/arch-distro/rollback-demo"
DEMO_FILES=(alpha.conf beta.conf gamma.conf)

dir="$(results_dir tema-03-rollback)"
log="$dir/demo.txt"
sudo mkdir -p "$DEMO_DIR"
for f in "${DEMO_FILES[@]}"; do
    echo "setting=$f original" | sudo tee "$DEMO_DIR/$f" >/dev/null
done
before="$(ad-snap take "demo: before destructive change" | tail -n1)"
run_logged "$log" ls -l "$DEMO_DIR"

say "Destructive change: delete two files, corrupt the third"
sudo rm "$DEMO_DIR/alpha.conf" "$DEMO_DIR/beta.conf"
echo "garbage" | sudo tee "$DEMO_DIR/gamma.conf" >/dev/null
after="$(ad-snap take "demo: after destructive change" | tail -n1)"
run_logged "$log" ls -l "$DEMO_DIR"
run_logged "$log" ad-snap diff "$before" "$after"

say "Rollback of the changes between $before and $after"
run_logged "$log" ad-snap undo "$before" "$after"
run_logged "$log" ls -l "$DEMO_DIR"
run_logged "$log" cat "$DEMO_DIR/gamma.conf"
ok "results in $dir"
