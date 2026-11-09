# shellcheck shell=bash
# Step 1: base layer. Runs arch-config's own install.sh (bspwm, sxhkd,
# alacritty, lemonbar, dotfiles) from a staged copy, trimmed to the desktop:
# development packages and the nvm/pnpm/Claude/go section are removed from
# the copy. The original clone is never modified. Requires lib/log.sh, lib/fsutil.sh and config/settings.sh.

ensure_arch_config_clone() {
    if [[ -d "$ARCH_CONFIG_DIR/.git" ]]; then
        ok "arch-config present at $ARCH_CONFIG_DIR"
        return
    fi
    say "Cloning arch-config into $ARCH_CONFIG_DIR"
    git clone --depth=1 "$ARCH_CONFIG_URL" "$ARCH_CONFIG_DIR"
}

# filter_list LIST SKIP -> rewrites LIST in place without SKIP entries.
filter_list() {
    local list="$1" skip="$2" tmp
    tmp="$(mktemp)"
    grep -vxF -f <(read_list "$skip") "$list" > "$tmp" || true
    mv "$tmp" "$list"
}

# drop_section SCRIPT START END -> deletes lines from the one starting with
# START up to (not including) the one starting with END. Fails loudly if the
# markers moved, instead of silently running the developer section.
drop_section() {
    local script="$1" start="$2" end="$3" tmp
    grep -q "^$start" "$script" && grep -q "^$end" "$script" \
        || die "markers '$start' / '$end' not found in arch-config install.sh"
    tmp="$(mktemp)"
    awk -v s="$start" -v e="$end" \
        'index($0, s) == 1 { skip = 1 } index($0, e) == 1 { skip = 0 } !skip' \
        "$script" > "$tmp"
    mv "$tmp" "$script"
}

step_base() {
    ensure_arch_config_clone
    local stage
    stage="$(mktemp -d)"
    # shellcheck disable=SC2064  # expand now: stage is local
    trap "rm -rf '$stage'" RETURN
    cp -a "$ARCH_CONFIG_DIR/." "$stage/"
    filter_list "$stage/pacman/pacman-packages.txt" "$REPO_DIR/$BASE_SKIP_PACMAN_FILE"
    filter_list "$stage/aur/aur-packages.txt" "$REPO_DIR/$BASE_SKIP_AUR_FILE"
    drop_section "$stage/install.sh" "$BASE_SKIP_SECTION_START" "$BASE_SKIP_SECTION_END"
    say "Running arch-config installer from staged copy"
    bash "$stage/install.sh"
}
