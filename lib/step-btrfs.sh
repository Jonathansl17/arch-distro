# shellcheck shell=bash
# Step: automatic btrfs snapshots with snapper (theme 3).
# Skipped with a warning when / is not btrfs (see docs/instalacion.md).

configure_snapper_limits() {
    sudo snapper -c "$SNAPPER_CONFIG" set-config \
        "TIMELINE_CREATE=yes" \
        "TIMELINE_LIMIT_HOURLY=$SNAPPER_TIMELINE_HOURLY" \
        "TIMELINE_LIMIT_DAILY=$SNAPPER_TIMELINE_DAILY" \
        "TIMELINE_LIMIT_WEEKLY=0" \
        "TIMELINE_LIMIT_MONTHLY=0" \
        "TIMELINE_LIMIT_YEARLY=0"
}

step_btrfs() {
    if [[ "$(root_fstype)" != "btrfs" ]]; then
        warn "root is $(root_fstype), not btrfs: skipping snapper (theme 3)"
        return
    fi
    if sudo snapper list-configs | awk '{print $1}' | grep -qx "$SNAPPER_CONFIG"; then
        ok "snapper config '$SNAPPER_CONFIG' exists"
    else
        say "Creating snapper config '$SNAPPER_CONFIG' for /"
        sudo snapper -c "$SNAPPER_CONFIG" create-config /
    fi
    configure_snapper_limits
    sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
}
