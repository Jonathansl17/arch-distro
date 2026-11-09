#!/usr/bin/env bash
# Theme 9: run this on ANOTHER machine or VM on the same network (the host,
# or a second VM). Expected: only 22/tcp open, everything else filtered
# (policy drop answers nothing, so nmap cannot tell "closed" from "dropped").
#   ./exp-09-nmap-remote.sh 192.168.122.50
set -euo pipefail

TARGET="${1:?usage: $0 TARGET_IP}"
OUT="nmap-$(date +%Y%m%d-%H%M%S)"
TOP_UDP_PORTS=50

command -v nmap >/dev/null || { echo "install nmap first" >&2; exit 1; }
echo "$ sudo nmap -Pn -sS -p- --reason $TARGET"
sudo nmap -Pn -sS -p- --reason -oN "$OUT-tcp.txt" "$TARGET"
echo "$ sudo nmap -Pn -sU --top-ports $TOP_UDP_PORTS $TARGET"
sudo nmap -Pn -sU --top-ports "$TOP_UDP_PORTS" --reason -oN "$OUT-udp.txt" "$TARGET"
echo "saved $OUT-tcp.txt and $OUT-udp.txt"
