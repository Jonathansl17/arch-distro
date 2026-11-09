#!/usr/bin/env bash
# Theme 9 experiment: positive and negative tests of every control.
# Every "expect: DENIED" line must fail; every "expect: OK" must succeed.
# The nmap scan runs from ANOTHER machine: experiments/exp-09-nmap-remote.sh
# Output: results/tema-09/<ts>/
set -euo pipefail
source "$(dirname "$0")/common.sh"
require getfacl nft ss

dir="$(results_dir tema-09)"
log="$dir/tests.txt"

# check EXPECT DESCRIPTION CMD... -> logs whether the result matched.
check() {
    local expect="$1" desc="$2" rc=0
    shift 2
    "$@" >> "$dir/raw.txt" 2>&1 || rc=$?
    local got="OK"
    (( rc == 0 )) || got="DENIED"
    printf '%-7s expected=%-6s got=%-6s %s\n' \
        "$([[ $got == "$expect" ]] && echo PASS || echo FAIL)" "$expect" "$got" "$desc" \
        | tee -a "$log"
}

as() { sudo -u "$1" "${@:2}"; }

check OK     "$OPERATOR_USER writes in $SHARED_DIR"   as "$OPERATOR_USER" touch "$SHARED_DIR/from-ana"
check DENIED "$READONLY_USER writes in $SHARED_DIR"   as "$READONLY_USER" touch "$SHARED_DIR/from-beto"
check OK     "$READONLY_USER lists $SHARED_DIR"       as "$READONLY_USER" ls "$SHARED_DIR"
check DENIED "$READONLY_USER deletes ana's file"      as "$READONLY_USER" rm -f "$SHARED_DIR/from-ana"
check OK     "$OPERATOR_USER restarts ad-monitor"     as "$OPERATOR_USER" sudo -n /usr/bin/systemctl restart ad-monitor.service
check DENIED "$OPERATOR_USER restarts sshd"           as "$OPERATOR_USER" sudo -n /usr/bin/systemctl restart sshd.service
check DENIED "$OPERATOR_USER systemctl edit (root shell)" as "$OPERATOR_USER" sudo -n /usr/bin/systemctl edit ad-monitor.service
check DENIED "$OPERATOR_USER reads /etc/shadow"       as "$OPERATOR_USER" sudo -n /usr/bin/cat /etc/shadow
check DENIED "$READONLY_USER uses sudo at all"        as "$READONLY_USER" sudo -n /usr/bin/nft list ruleset
check DENIED "root login over ssh allowed"            bash -c "sudo sshd -T | grep -qx 'permitrootlogin yes'"

run_logged "$dir/state.txt" as "$OPERATOR_USER" sudo -n -l
run_logged "$dir/state.txt" getfacl -p "$SHARED_DIR"
run_logged "$dir/state.txt" sudo nft list ruleset
run_logged "$dir/state.txt" ss -tlnp
run_logged "$dir/state.txt" ip -br addr
sudo rm -f "$SHARED_DIR/from-ana"
if grep -q '^FAIL' "$log"; then
    warn "some checks FAILED, see $log"
else
    ok "all checks passed"
fi
ok "results in $dir"
