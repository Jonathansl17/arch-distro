# shellcheck shell=bash
# Single source of every tunable value used by install.sh and experiments/.
# Sourced, never executed. Change values here, not in the scripts.

# --- Base layer (arch-config, applied untouched from a staged copy) ---
ARCH_CONFIG_URL="https://github.com/Jonathansl17/arch-config.git"
ARCH_CONFIG_DIR="${ARCH_CONFIG_DIR:-$HOME/arch-config}"
# Packages dropped from arch-config's lists when staging it (one per line):
# the distro keeps the desktop, not the author's development tools.
BASE_SKIP_PACMAN_FILE="config/base-skip-pacman.txt"
BASE_SKIP_AUR_FILE="config/base-skip-aur.txt"
# Section of arch-config's install.sh removed from the staged copy: nvm,
# pnpm, Claude Code and go tools (developer setup fetched with curl/go).
BASE_SKIP_SECTION_START="# --- 4e. nvm"
BASE_SKIP_SECTION_END="# --- 4f. sysctl"

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
