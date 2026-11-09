#!/usr/bin/env bash
# ad-report.sh - body of ad-report.service, fired by ad-report.timer.
# Writes a daily health report to $LOGS_DIRECTORY (set by LogsDirectory=).
set -euo pipefail

out="${LOGS_DIRECTORY:?run me from ad-report.service}/report-$(date +%F).log"
{
    echo "# arch-distro report $(date -Is)"
    echo "## uptime";        cat /proc/uptime
    echo "## memory";        free -h
    echo "## swap devices";  cat /proc/swaps
    echo "## disk";          df -h -x tmpfs -x devtmpfs
    echo "## failed units";  systemctl --failed --no-legend --plain || true
    echo "## pressure";      grep -H . /proc/pressure/*
} > "$out"
echo "report written to $out"
