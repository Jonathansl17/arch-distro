# shellcheck shell=bash
# Step: monitor environment file + enable/start the units in config/services.txt.

MONITOR_ENV_DEFAULT="INTERVAL_SECS=10
LOAD_WORKERS=0
LOAD_MEM_MIB=0"

ensure_monitor_env() {
    # Created once; experiments edit it later, so never overwrite.
    if sudo test -f "$MONITOR_ENV_FILE"; then
        ok "$MONITOR_ENV_FILE exists (left as is)"
        return
    fi
    echo "$MONITOR_ENV_DEFAULT" | sudo install -Dm644 /dev/stdin "$MONITOR_ENV_FILE"
    say "created $MONITOR_ENV_FILE"
}

step_services() {
    local units unit
    ensure_monitor_env
    mapfile -t units < <(read_list "$REPO_DIR/config/services.txt")
    for unit in "${units[@]}"; do
        if systemctl is-enabled --quiet "$unit" && systemctl is-active --quiet "$unit"; then
            ok "$unit enabled and active"
        else
            sudo systemctl enable --now "$unit"
            say "enabled $unit"
        fi
    done
}
