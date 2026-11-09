#!/usr/bin/env bash
# One-screen digest of the latest results of every experiment, sized to fit
# a single screenshot. Called at the end of run-all.sh; can be rerun alone:
#   experiments/summary.sh jonathan
set -uo pipefail
source "$(dirname "$0")/common.sh"

member="${1:-$USER}"
RES="$EXP_REPO/results"
MIB_PER_KIB=1024

# latest THEME -> newest results/<theme>/<ts> directory, empty if none.
latest() { find "$RES/$1" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n1; }
plain() { sed 's/\x1b\[[0-9;]*m//g'; }
h() { printf '\033[1;36m%s\033[0m\n' "$*"; }
missing() { echo "  (no results)"; }

capa1() {
    local f="$EXP_REPO/logs/$member/capa1-evidence.txt"
    h "Capa 1  UEFI=$(cat /sys/firmware/efi/fw_platform_size 2>/dev/null || echo NO)-bit  root=$(findmnt -no FSTYPE /)  kernel=$(uname -r)"
    [[ -f "$f" ]] && grep -m1 'Product:' "$f" | sed 's/^ */  loader: /'
}

t1() {
    local d; d="$(latest tema-01)"; h "T1 scheduling (nice pair: measured vs expected share)"
    [[ -n "$d" ]] || { missing; return; }
    awk -F, 'NR > 1 { printf "  nice %3s/%-3s cpu %5.1f%% / %5.1f%%   share %.3f (expected %.3f)\n", $1, $2, $3, $4, $5, $6 }' "$d/shares.csv"
    awk 'BEGIN { printf "  RT test:" } $5 == "FIFO" || $5 == "OTHER" { printf "  %s %s%%", $5, $8 } END { print "" }' "$d/rt.txt"
}

t2() {
    local d l; d="$(latest tema-02)"; h "T2 memory (with vs without zram)"
    [[ -n "$d" ]] || { missing; return; }
    for l in with without; do
        awk -F, -v l="$l" 'NR > 1 { if ($7 > mj) mj = $7; if ($3 > sw) sw = $3
                if ($4 > zo) { zo = $4; zc = $5 } }
            END { printf "  %-8s peak majflt/s=%d  peak swap=%d MiB  zram ratio=%.1f", l, mj, sw / 1024, zc ? zo / zc : 0 }' \
            "$d/$l-admem.csv"
        printf '  oom=%s\n' "$(grep -qi 'killed process' "$d/$l-oom.txt" && echo YES || echo no)"
        grep -h 'metrc.* vm ' "$d/$l-stress.txt" | awk '{ printf "           bogo ops=%s  ops/s(real)=%s\n", $5, $9 }'
    done
    sed 's/^/  /' "$d/summary.txt"
}

t3() {
    local d r; d="$(latest tema-03)"; h "T3 fio, avg of runs (MiB/s / IOPS)   btrfs | ext4"
    [[ -n "$d" ]] || { missing; return; }
    awk -F, -v k="$MIB_PER_KIB" 'NR > 1 { w = ($2 ~ /write/); bw = w ? $6 : $4; io = w ? $7 : $5
            b[$1, $2] += bw; i[$1, $2] += io; n[$1, $2]++; jobs[$2] = 1 }
        END { for (j in jobs) printf "  %-10s %8.1f / %-8.0f | %8.1f / %-8.0f\n", j,
              b["btrfs", j] / n["btrfs", j] / k, i["btrfs", j] / n["btrfs", j],
              b["ext4", j] / n["ext4", j] / k, i["ext4", j] / n["ext4", j] }' "$d/fio.csv" | sort
    r="$(latest tema-03-rollback)"
    [[ -n "$r" ]] && echo "  rollback: $(grep -q 'setting=gamma.conf original' "$r/demo.txt" && echo restored OK || echo NOT restored)"
}

t4() {
    local d; d="$(latest tema-04)"; h "T4 ad-monitor.service limits"
    [[ -n "$d" ]] || { missing; return; }
    grep -h 'unit CPU over' "$d/2-quota.txt" | sed 's/^/  /'
    grep -h 'throttled' "$d/2-quota.txt" | tail -n1 | sed 's/^ */  /'
    grep -h 'oom kills' "$d/3-memory.txt" | tail -n1 | sed 's/^ */  /'
    grep -hE 'restarted|no restart' "$d/4-restart.txt" | plain | sed 's/^/  /'
}

t5() {
    local d; d="$(latest tema-05)"; h "T5 ad-ipc"
    [[ -n "$d" ]] || { missing; return; }
    echo "  safe:   $(grep -c 'exit=0' "$d/2-safe.txt")/$(grep -c '^run' "$d/2-safe.txt") exact   $(grep -m1 '^files' "$d/2-safe.txt")"
    echo "  unsafe: $(grep -c 'exit=3' "$d/2-unsafe.txt")/$(grep -c '^run' "$d/2-unsafe.txt") wrong   $(grep -m1 '^files' "$d/2-unsafe.txt")"
    echo "  SIGTERM: $(grep -h 'ad-ipc exit' "$d/3-sigterm.txt" | cut -d' ' -f2)  $(grep -h '^zombies' "$d/3-sigterm.txt")  $(grep -h '^shm_left' "$d/3-sigterm.txt")"
}

t6() {
    local d; d="$(latest tema-06)"; h "T6 package + hook"
    [[ -n "$d" ]] || { missing; return; }
    echo "  $(grep -hE '^(Version|Installed Size)' "$d/1-package.txt" | tr -s ' ' | paste -sd' ')"
    grep -hA1 'arch-distro: checking' "$d/3-transaction.txt" | plain | sed 's/^ */  /'
}

t7() {
    h "T7 boot (s): label,boot,firmware,loader,kernel,initrd,userspace"
    tail -n +2 "$RES/tema-07/boots.csv" 2>/dev/null | cut -d, -f1,3- | sed 's/^/  /' || missing
}

t8() {
    local d; d="$(latest tema-08)"; h "T8 devices"
    [[ -n "$d" ]] || { missing; return; }
    grep -hE '^\s+(GPU|NPU|driver)' "$d/3-drivers.txt" | plain | sed 's/^ */  /'
    echo "  blacklisted loaded: $(tail -n2 "$d/2-blacklist.txt" | head -n1)"
    echo "  top IRQs during dd: $(sed -n '/interrupts raised/,$p' "$d/4-interrupts.txt" | sed -n '2,4p' | cut -c1-40 | paste -sd'|')"
    echo "  USB add events logged: $(grep -c ' add /dev' "$d/5-udev.txt")"
}

t9() {
    local d; d="$(latest tema-09)"; h "T9 security"
    [[ -n "$d" ]] || { missing; return; }
    echo "  checks PASS $(grep -c '^PASS' "$d/tests.txt")/$(grep -c . "$d/tests.txt")"
    grep -h '^FAIL' "$d/tests.txt" | sed 's/^/  /'
}

capa1; t1; t2; t3; t4; t5; t6; t7; t8; t9
