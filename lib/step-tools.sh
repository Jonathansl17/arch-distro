# shellcheck shell=bash
# Step: build and install the arch-distro-tools pacman package (theme 6).
# Rebuilds only when the packaged sources changed, so re-runs are no-ops.

# tools_hash -> sha256 over every file the PKGBUILD packages.
tools_hash() {
    (cd "$REPO_DIR" && find src bin lib config/settings.sh systemd udev modprobe pacman -type f \
        ! -path 'src/build/*' ! -path 'pacman/pkg/*' ! -path 'pacman/src/*' ! -name '*.pkg.tar.*' \
        -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
}

tools_up_to_date() {
    local current="$1"
    pacman -Q "$TOOLS_PKG_NAME" >/dev/null 2>&1 || return 1
    sudo test -f "$TOOLS_HASH_FILE" || return 1
    [[ "$(sudo cat "$TOOLS_HASH_FILE")" == "$current" ]]
}

build_and_install_tools() {
    local pkgdir="$REPO_DIR/pacman" pkgfile
    (cd "$pkgdir" && makepkg -f --cleanbuild --noconfirm)
    pkgfile="$(cd "$pkgdir" && makepkg --packagelist | head -n1)"
    [[ -f "$pkgfile" ]] || die "makepkg produced no package"
    sudo pacman -U --noconfirm "$pkgfile"
}

step_tools() {
    local current
    current="$(tools_hash)"
    if tools_up_to_date "$current"; then
        ok "$TOOLS_PKG_NAME up to date"
        return
    fi
    say "Building $TOOLS_PKG_NAME with makepkg"
    build_and_install_tools
    echo "$current" | sudo install -Dm644 /dev/stdin "$TOOLS_HASH_FILE"
    sudo systemctl daemon-reload
    sudo udevadm control --reload
}
