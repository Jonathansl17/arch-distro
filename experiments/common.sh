# shellcheck shell=bash
# Shared helpers for experiments/*.sh. Every experiment writes into
# results/<theme>/<timestamp>/ inside the repo, recording each exact command
# next to its output so the evidence sheet (docs/tema-*.md) can quote it.

EXP_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/log.sh
source "$EXP_REPO/lib/log.sh"
# shellcheck source=../config/settings.sh
source "$EXP_REPO/config/settings.sh"

# results_dir THEME -> creates and prints a fresh results directory.
results_dir() {
    local dir
    dir="$EXP_REPO/results/$1/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$dir"
    {
        echo "host: $(uname -n)"
        echo "kernel: $(uname -r)"
        echo "date: $(date -Is)"
        echo "cpus: $(nproc)"
        echo "mem_total_kib: $(awk '/^MemTotal/ {print $2}' /proc/meminfo)"
    } > "$dir/environment.txt"
    echo "$dir"
}

# run_logged FILE CMD... -> prints "$ CMD", runs it, tees both into FILE.
run_logged() {
    local file="$1"
    shift
    {
        printf '$ %s\n' "$*"
        "$@" 2>&1
        printf '[exit %d]\n\n' "$?"
    } | tee -a "$file"
}

require() {
    local cmd
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null || die "missing command: $cmd (run install.sh)"
    done
}
