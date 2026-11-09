# shellcheck shell=bash
# Step 1: base layer. Runs arch-config's own install.sh (bspwm, sxhkd,
# alacritty, packages, dotfiles) from a staged copy so the original clone is
# never modified. Requires lib/log.sh, lib/fsutil.sh and config/settings.sh.

ensure_arch_config_clone() {
    if [[ -d "$ARCH_CONFIG_DIR/.git" ]]; then
        ok "arch-config present at $ARCH_CONFIG_DIR"
        return
    fi
    say "Cloning arch-config into $ARCH_CONFIG_DIR"
    git clone --depth=1 "$ARCH_CONFIG_URL" "$ARCH_CONFIG_DIR"
}

# filter_aur_list LIST SKIP -> rewrites LIST in place without SKIP entries.
filter_aur_list() {
    local list="$1" skip="$2" tmp
    tmp="$(mktemp)"
    grep -vxF -f <(read_list "$skip") "$list" > "$tmp" || true
    mv "$tmp" "$list"
}

step_base() {
    ensure_arch_config_clone
    local stage
    stage="$(mktemp -d)"
    # shellcheck disable=SC2064  # expand now: stage is local
    trap "rm -rf '$stage'" RETURN
    cp -a "$ARCH_CONFIG_DIR/." "$stage/"
    filter_aur_list "$stage/aur/aur-packages.txt" "$REPO_DIR/$BASE_AUR_SKIP_FILE"
    say "Running arch-config installer from staged copy"
    bash "$stage/install.sh"
}
