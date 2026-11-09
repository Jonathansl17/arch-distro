# shellcheck shell=bash
# Step: swap file + zram (theme 2). Requires log.sh, fsutil.sh, settings.sh.

create_swapfile() {
    local dir
    dir="$(dirname "$SWAPFILE_PATH")"
    if [[ "$(root_fstype)" == "btrfs" ]]; then
        # btrfs cannot snapshot a subvolume holding an active swap file, so
        # the swap file needs its own subvolume (excluded from snapshots of /).
        # A manual install already mounts @swap there; otherwise create one.
        [[ -d "$dir" ]] || sudo btrfs subvolume create "$dir"
        # mkswapfile sets NOCOW and disables compression, both required for
        # swap on btrfs (the kernel needs fixed physical extents).
        sudo btrfs filesystem mkswapfile --size "${SWAPFILE_SIZE_MIB}m" "$SWAPFILE_PATH"
    else
        sudo mkdir -p "$dir"
        sudo fallocate -l "${SWAPFILE_SIZE_MIB}M" "$SWAPFILE_PATH"
        sudo chmod 600 "$SWAPFILE_PATH"
        sudo mkswap "$SWAPFILE_PATH" >/dev/null
    fi
    say "created swap file $SWAPFILE_PATH (${SWAPFILE_SIZE_MIB} MiB)"
}

register_swapfile() {
    local entry="$SWAPFILE_PATH none swap defaults,pri=$SWAPFILE_PRIORITY 0 0"
    if grep -qF "$SWAPFILE_PATH" /etc/fstab; then
        ok "fstab already lists $SWAPFILE_PATH"
    else
        echo "$entry" | sudo tee -a /etc/fstab >/dev/null
        say "added swap file to /etc/fstab"
    fi
    if swapon --show=NAME --noheadings | grep -qxF "$SWAPFILE_PATH"; then
        ok "swap file already active"
    else
        sudo swapon -p "$SWAPFILE_PRIORITY" "$SWAPFILE_PATH"
    fi
}

step_memory() {
    [[ -f "$SWAPFILE_PATH" ]] || create_swapfile
    register_swapfile
    if install_root "$REPO_DIR/memory/zram-generator.conf" \
        /etc/systemd/zram-generator.conf 644; then
        # The generator turns the config into systemd-zram-setup@zram0.service
        # (creates the device) and dev-zram0.swap (swapon with the priority).
        sudo systemctl daemon-reload
        sudo systemctl stop dev-zram0.swap
        sudo systemctl restart systemd-zram-setup@zram0.service
        sudo systemctl start dev-zram0.swap
    fi
}
