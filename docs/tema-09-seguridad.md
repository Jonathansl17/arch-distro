# Theme 9: Protection and security · Owner: Jennifer López Miranda

## 1. What was implemented

All of it is in `lib/step-security.sh` and `security/`. Names come from
`config/settings.sh`.

- **Users and groups with least privilege.** Group `proyecto` (shared work)
  and group `operadores` (service operators). User `ana` is in both. User
  `beto` is only in `proyecto`. Both have locked passwords and are used with
  `sudo -u` for the tests.
- **Shared directory** `/srv/proyecto`: `root:proyecto`, mode `2770` (setgid,
  so new files get the group). ACL `g:proyecto:rwx`, and a named entry
  `u:beto:r-x`. The named user entry is checked before the group entries, so
  beto is read-only even though he is in the group. Default ACLs copy the
  same rules to new files.
- **sudoers by command** (`security/sudoers.d/arch-distro`, checked with
  `visudo -c`). `%operadores` may only start, stop and restart
  `ad-monitor.service`, read its journal with `--no-pager`, and list the
  firewall. Exact paths and arguments: a pattern like `systemctl *` would
  allow `systemctl edit` (editor as root, a root shell), and a pager can run
  `!sh`.
- **nftables** (`security/nftables.conf`). `inet` table, input policy `drop`.
  Accepts established/related, loopback, rate-limited ping, the IPv6 neighbour
  discovery messages, and SSH (new connections limited to 10/min). Logs drops
  at 5/min. Forward drop. arch-config's ufw is disabled to keep a single policy.
- **SSH hardening** (`security/sshd_config.d/10-arch-distro.conf`). No root
  login, keys only, `AllowGroups wheel`, `MaxAuthTries 3`, no X11 or agent
  forwarding.
- `ad-sec` (`bin/ad-sec`): one report with all of the above, plus `fails`
  (failed sudo and ssh attempts from the journal).

## 2. Operating systems concept

- Protection domains, access matrix, ACLs, the principle of least privilege,
  authentication, firewalls. Silberschatz et al. 10th ed., ch. 16 (Security)
  and ch. 17 (Protection: access matrix, ACLs, least privilege).
- Linux DAC: owner/group/other bits, extended by POSIX ACLs. The `mask` entry
  is the maximum any group or named-user entry can grant.
- Netfilter hooks in the kernel's network stack. nftables loads a ruleset
  that is evaluated per packet at the `input` hook.

## 3. Measurement method

```sh
experiments/exp-09-sec.sh                       # on the distro
experiments/exp-09-nmap-remote.sh <VM_IP>       # on the HOST or another VM
```

`exp-09-sec.sh` runs 10 checks, each with an expected outcome, and prints
PASS/FAIL: ana writes, beto cannot write or delete, ana can restart the
monitor but not sshd, `systemctl edit`, or `cat /etc/shadow`, beto has no sudo,
root login over ssh is off. It also saves `sudo -l` of ana, `getfacl`,
`nft list ruleset`, `ss -tlnp`. The remote script runs `nmap -Pn -sS -p-`
and `-sU --top-ports 50`.

## 4. Results

Pending (VM). Paste `tests.txt` (10 lines PASS/FAIL), the interpreted
ruleset and the nmap summary.

| Check | Expected | Got |
|-------|----------|-----|
| beto touch in /srv/proyecto | DENIED | |
| ana restart sshd via sudo | DENIED | |
| ana systemctl edit via sudo | DENIED | |
| nmap TCP open ports | 22 only | |

## 5. Interpretation

Pending. Explain each DENIED with the rule that caused it (ACL entry,
sudoers alias, missing group). Explain why nmap shows "filtered" and not
"closed" for the other ports: policy drop sends no RST. Explain why the
`limit rate` on new SSH connections slows a brute-force attempt but does not
affect an established session.
