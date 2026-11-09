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

VM `192.168.122.141`. Raw data: `results/tema-09/<ts>/tests.txt`, `raw.txt`.

**Negative and positive checks** (`tests.txt`, last run 19:36 UTC):

| Check | Expected | Got |
|-------|----------|-----|
| ana writes in `/srv/proyecto` | OK | OK |
| beto writes in `/srv/proyecto` | DENIED | DENIED |
| beto lists `/srv/proyecto` | OK | OK |
| beto deletes ana's file | DENIED | DENIED |
| ana restarts `ad-monitor` via sudo | OK | OK |
| ana restarts `sshd` via sudo | DENIED | DENIED |
| ana `systemctl edit` via sudo (root shell) | DENIED | DENIED |
| ana reads `/etc/shadow` | DENIED | DENIED |
| beto uses sudo at all | DENIED | DENIED |
| root login over ssh allowed | DENIED | DENIED |

10/10 PASS in the last 3 runs (18:56, 19:16, 19:36 UTC). The first run
(18:11 UTC) gave 7/10 because the security step had not been applied yet:
`sudo: unknown user ana`.

**ana's sudo rights** (`sudo -n -l` as ana):

```text
(root) NOPASSWD: /usr/bin/systemctl start ad-monitor.service,
  /usr/bin/systemctl stop ad-monitor.service,
  /usr/bin/systemctl restart ad-monitor.service,
  /usr/bin/journalctl --no-pager -u ad-monitor.service, /usr/bin/nft list ruleset
Defaults: timestamp_timeout=0, use_pty, secure_path=...
```

**ACL** (`getfacl -p /srv/proyecto`): owner `root`, group `proyecto`, flags
`-s-` (setgid); `user:beto:r-x`, `group:proyecto:rwx`, `mask::rwx`,
`other::---`, and the same entries as `default:` for new files.

**Ruleset** (`nft list ruleset`, input chain):

```text
type filter hook input priority filter; policy drop;
ct state established,related accept
ct state invalid drop
iif "lo" accept
ip protocol icmp icmp type echo-request limit rate 5/second burst 5 packets accept
ip6 nexthdr ipv6-icmp icmpv6 type { echo-request, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
tcp dport 22 ct state new limit rate 10/minute burst 5 packets accept
limit rate 5/minute burst 5 packets log prefix "nft-drop: " level info
```

Forward chain: policy drop, no rules. Output chain: policy accept.
Listening sockets (`ss -tlnp`): only `0.0.0.0:22` and `[::]:22`.

**Remote scan from the host**
(`experiments/exp-09-nmap-remote.sh 192.168.122.141`):

```text
$ sudo nmap -Pn -sS -p- --reason 192.168.122.141
Not shown: 65534 filtered tcp ports (no-response)
PORT   STATE SERVICE REASON
22/tcp open  ssh     syn-ack ttl 64

$ sudo nmap -Pn -sU --top-ports 50 --reason 192.168.122.141
All 50 scanned ports on 192.168.122.141 are in ignored states.
Not shown: 50 open|filtered udp ports (no-response)
```


## 5. Interpretation

- **ACL order decides beto's access.** beto is in `proyecto`, whose entry
  grants `rwx`, yet he cannot write. POSIX ACL checks go in a fixed order:
  owner, then named users, then groups, then other. The first matching
  class wins, so `user:beto:r-x` applies and the `proyecto` entry is never
  consulted for him. He can list (r-x) but not create or delete. ana, with
  no named entry, falls to the group entries and gets `rwx`, masked by
  `mask::rwx`. The setgid bit makes her files belong to `proyecto`, so the
  rest of the group can work on them.
- **beto cannot delete ana's file** because deleting is a write on the
  directory, not on the file, and his effective rights on the directory
  have no `w`.
- **sudoers by exact command.** ana can run only the 5 listed command lines,
  with those exact arguments. `systemctl restart sshd` and `systemctl edit`
  do not match any line, so sudo refuses before running anything. That is
  the point of not writing `systemctl *`: `systemctl edit` opens an editor
  as root, and an editor can start a shell. `journalctl` is listed with
  `--no-pager` for the same reason, because the pager (`less`) can run
  `!sh`. `/etc/shadow` is mode 0600 root, and ana has no sudo line for it.
  beto is not in `operadores`, so sudo has no line at all for him.
- **Default deny in the firewall.** The input chain's policy is drop: any
  packet that no rule accepts is discarded without an answer. The rules
  accept only replies to connections the VM opened, loopback, limited ping,
  the IPv6 neighbour discovery messages (without them IPv6 stops working),
  and new SSH connections at most 10 per minute. `ct state invalid drop`
  discards packets that do not belong to any valid connection state.
- **Why the SSH limit does not hurt real use.** The limit applies only to
  `ct state new`. Once a session is established its packets match the first
  rule (`established,related`), so the limit never touches it. A brute-force
  tool needs many new connections, and those are throttled to 10 per minute.
- **What nmap shows.** With policy drop, a closed port sends
  nothing back, not even a TCP RST, so nmap reports the other ports as
  `filtered` instead of `closed`. Only 22/tcp is `open`, and the other
  65 534 TCP ports are `filtered` with reason `no-response`. UDP shows `open|filtered`: with no reply nmap cannot tell an open
  UDP port from a dropped one. `ss` agrees: 22 is the only
  listening TCP port.
