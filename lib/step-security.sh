# shellcheck shell=bash
# Step: users, groups, sudoers, shared directory ACL, nftables, sshd (theme 9).
# Requires log.sh, fsutil.sh and settings.sh.

ensure_group() {
    getent group "$1" >/dev/null && return
    sudo groupadd "$1"
    say "created group $1"
}

# ensure_user NAME GROUPS -> system-less regular user with a locked password.
ensure_user() {
    local name="$1" groups="$2"
    if ! id "$name" >/dev/null 2>&1; then
        sudo useradd -m -s /bin/bash "$name"
        sudo passwd -l "$name" >/dev/null
        say "created user $name (password locked)"
    fi
    sudo usermod -aG "$groups" "$name"
}

setup_accounts() {
    ensure_group "$SHARED_GROUP"
    ensure_group "$OPERATOR_GROUP"
    ensure_user "$OPERATOR_USER" "$SHARED_GROUP,$OPERATOR_GROUP"
    ensure_user "$READONLY_USER" "$SHARED_GROUP"
    sudo usermod -aG "$SHARED_GROUP" "$USER"
}

# Group rwx + setgid so new files belong to the group; beto gets a named ACL
# entry (r-x) that wins over his group membership; defaults are inherited.
setup_shared_dir() {
    sudo install -d -o root -g "$SHARED_GROUP" -m 2770 "$SHARED_DIR"
    sudo setfacl -m "u:$READONLY_USER:r-x,g:$SHARED_GROUP:rwx,o::---" "$SHARED_DIR"
    sudo setfacl -d -m "u:$READONLY_USER:r-x,g:$SHARED_GROUP:rwx,o::---" "$SHARED_DIR"
    ok "shared dir $SHARED_DIR: $(getfacl -cp "$SHARED_DIR" 2>/dev/null | tr '\n' ' ')"
}

install_sudoers() {
    local rendered
    rendered="$(mktemp)"
    sed "s/@OPERATOR_GROUP@/$OPERATOR_GROUP/g" \
        "$REPO_DIR/security/sudoers.d/arch-distro" > "$rendered"
    sudo visudo -cqf "$rendered" || die "sudoers rule does not validate"
    install_root "$rendered" /etc/sudoers.d/arch-distro 440 || :  # 1 = unchanged
    rm -f "$rendered"
}

setup_firewall() {
    if systemctl is-enabled --quiet ufw.service 2>/dev/null; then
        say "Disabling ufw (arch-config) in favour of native nftables"
        sudo ufw disable >/dev/null
        sudo systemctl disable --now ufw.service
    fi
    if install_root "$REPO_DIR/security/nftables.conf" /etc/nftables.conf 644; then
        sudo nft -c -f /etc/nftables.conf || die "nftables.conf does not parse"
        sudo systemctl restart nftables.service
    fi
}

setup_sshd() {
    if install_root "$REPO_DIR/security/sshd_config.d/10-arch-distro.conf" \
        /etc/ssh/sshd_config.d/10-arch-distro.conf 644; then
        sudo sshd -t || die "sshd config does not validate"
        sudo systemctl try-restart sshd.service
    fi
}

step_security() {
    setup_accounts
    setup_shared_dir
    install_sudoers
    setup_firewall
    setup_sshd
}
