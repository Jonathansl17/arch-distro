# shellcheck shell=bash
# Idempotent file and list helpers. Requires lib/log.sh.

# read_list FILE -> prints entries, stripping comments and blank lines.
read_list() {
    local file="$1"
    [[ -f "$file" ]] || die "list not found: $file"
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$file"
}

# install_root SRC DST MODE -> copies as root only when content differs.
# Returns 0 when the file changed, 1 when it was already up to date.
install_root() {
    local src="$1" dst="$2" mode="$3"
    [[ -f "$src" ]] || die "source missing: $src"
    if sudo test -f "$dst" && sudo cmp -s "$src" "$dst"; then
        ok "unchanged: $dst"
        return 1
    fi
    sudo install -Dm"$mode" "$src" "$dst"
    say "installed: $dst"
    return 0
}

# root_fstype -> prints the file system type mounted on /.
root_fstype() {
    findmnt -no FSTYPE /
}
