# shellcheck shell=bash
# Single source of every tunable value used by install.sh and experiments/.
# Sourced, never executed. Change values here, not in the scripts.

# --- Base layer (arch-config, applied untouched from a staged copy) ---
ARCH_CONFIG_URL="https://github.com/Jonathansl17/arch-config.git"
ARCH_CONFIG_DIR="${ARCH_CONFIG_DIR:-$HOME/arch-config}"
# AUR packages skipped when staging arch-config (one name per line).
BASE_AUR_SKIP_FILE="config/base-aur-skip.txt"

# --- Logs ---
LOG_DIR="$HOME/.local/state/arch-distro"
SYSTEM_LOG_DIR="/var/log/arch-distro"

# --- Package built from this repo (PKGBUILD in pacman/) ---
TOOLS_PKG_NAME="arch-distro-tools"
TOOLS_HASH_FILE="/var/lib/arch-distro/tools.sha256"

# --- Memory (theme 2) ---
SWAPFILE_PATH="/swap/swapfile"
SWAPFILE_SIZE_MIB=2048
SWAPFILE_PRIORITY=10

# --- Btrfs snapshots (theme 3) ---
SNAPPER_CONFIG="root"
SNAPPER_TIMELINE_HOURLY=5
SNAPPER_TIMELINE_DAILY=7

# --- Services (theme 4) ---
MONITOR_ENV_FILE="/etc/arch-distro/monitor.env"

# --- Protection and security (theme 9) ---
SHARED_GROUP="proyecto"
SHARED_DIR="/srv/proyecto"
OPERATOR_GROUP="operadores"
# Demo accounts for the negative tests (locked passwords, no login shell use).
OPERATOR_USER="ana"     # in SHARED_GROUP + OPERATOR_GROUP: rw + limited sudo
READONLY_USER="beto"    # in SHARED_GROUP, but a named ACL entry makes it r-x
