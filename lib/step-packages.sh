# shellcheck shell=bash
# Step: official packages from config/pkglist.txt (pacman --needed skips the
# ones already installed, so re-runs only check).

step_packages() {
    local pkgs
    mapfile -t pkgs < <(read_list "$REPO_DIR/config/pkglist.txt")
    (( ${#pkgs[@]} )) || die "config/pkglist.txt is empty"
    say "Installing ${#pkgs[@]} official packages"
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}
