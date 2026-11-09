#!/usr/bin/env bash
# Test suite: C unit tests, shell syntax (+ shellcheck when installed),
# unit tests of the pure shell helpers, and config-file validators that run
# without root. Usage: tests/run.sh
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
export REPO_DIR="$REPO"
# shellcheck source=../lib/log.sh
source "$REPO/lib/log.sh"
# shellcheck source=../lib/fsutil.sh
source "$REPO/lib/fsutil.sh"
# shellcheck source=../lib/step-base.sh
source "$REPO/lib/step-base.sh"

failures=0
pass() { ok "$1"; }
fail() { warn "FAIL: $1"; failures=$((failures + 1)); }
expect_eq() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1: expected '$3', got '$2'"; }

shell_files() {
    grep -rlE '^#!/usr/bin/env bash|shell=bash' "$REPO"/{install.sh,lib,bin,systemd,udev,pacman/hooks,experiments,tests} \
        2>/dev/null
}

test_c() {
    make -s -C "$REPO/src" BUILD="$(mktemp -d)" all test && pass "C build + unit tests" \
        || fail "C build or unit tests"
}

test_shell_syntax() {
    local f
    for f in $(shell_files); do
        bash -n "$f" || fail "bash -n $f"
    done
    pass "bash -n on $(shell_files | wc -l) scripts"
    if command -v shellcheck >/dev/null; then
        shellcheck -x $(shell_files) && pass "shellcheck" || fail "shellcheck"
    else
        warn "shellcheck not installed: lint skipped"
    fi
}

test_read_list() {
    local f
    f="$(mktemp)"
    printf '# comment\n\nfoo   # trailing\n  bar\n\t\n' > "$f"
    expect_eq "read_list strips comments and blanks" "$(read_list "$f" | xargs)" "foo bar"
    rm -f "$f"
}

test_filter_aur_list() {
    local list skip
    list="$(mktemp)"; skip="$(mktemp)"
    printf 'brave-bin\npackettracer\npackettracer-extra\n' > "$list"
    printf '# why\npackettracer\n' > "$skip"
    filter_aur_list "$list" "$skip"
    expect_eq "filter_aur_list removes exact names only" "$(xargs < "$list")" \
        "brave-bin packettracer-extra"
    rm -f "$list" "$skip"
}

test_configs() {
    command -v nft >/dev/null && unshare -rn true 2>/dev/null \
        && { unshare -rn nft -c -f "$REPO/security/nftables.conf" \
             && pass "nftables.conf parses" || fail "nftables.conf"; }
    command -v systemd-analyze >/dev/null && {
        local tmp; tmp="$(mktemp -d)"
        cp "$REPO"/systemd/*.service "$REPO"/systemd/*.timer "$tmp/"
        sed -i "s|/usr/lib/arch-distro/|$REPO/systemd/|" "$tmp"/ad-monitor.service "$tmp"/ad-report.service
        sed -i "s|/usr/lib/arch-distro/|$REPO/udev/|" "$tmp"/ad-usb-event@.service
        (cd "$tmp" && systemd-analyze verify --man=no ./ad-monitor.service ./ad-report.service \
            ./ad-report.timer ./ad-usb-event@test.service 2>&1 | grep -v 'not found' ) \
            && fail "systemd-analyze verify reported problems" || pass "unit files verify"
        rm -rf "$tmp"
    }
}

test_install_usage() {
    "$REPO/install.sh" --bogus >/dev/null 2>&1
    expect_eq "install.sh rejects unknown flags with exit 2" "$?" "2"
}

test_c
test_shell_syntax
test_read_list
test_filter_aur_list
test_configs
test_install_usage
(( failures == 0 )) && ok "all tests passed" || die "$failures test(s) failed"
