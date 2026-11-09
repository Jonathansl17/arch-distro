# AI usage log

Format from annex 3 of the statement. One entry per relevant query. Every
member logs their own entries for the themes they own.

## Context

The desktop this distribution runs on was not built for the project.
[arch-config](https://github.com/Jonathansl17/arch-config) is Jonathan's daily
Arch setup (bspwm, sxhkd, alacritty, lemonbar, PipeWire, NetworkManager) and it
existed before the course. The project never edits it.

So AI was not used to write a distribution from scratch. It was used for two
things. The first was building the operating-systems layer on top of
arch-config: the nine themes, the `ad-` commands, the package, the measurement
scripts and the docs. The second was trimming arch-config down to what a
course distribution needs. arch-config installs a full developer workstation
(docker, JDKs, node, postgres, LibreOffice, wine, TeX, VS Code, IntelliJ,
Packet Tracer, nvm, pnpm, Go...), and none of that has anything to do with the
themes. Instead of forking arch-config, `install.sh` stages a temporary copy
and removes those parts from it before running its installer.

Entries 1 and 2 cover that work. The rest are specific queries, most of them
errors in what the AI produced that we caught while building, running or
measuring.

## Entries

### 1 · Operating-systems layer on top of arch-config

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | Whole repository (structure, install.sh, src/, bin/, systemd/, docs) |
| Purpose | Generate a first version of the project layer on top of arch-config without modifying it |
| Query (prompt) | "I already have arch-config, my daily Arch setup with bspwm, sxhkd, alacritty and lemonbar. Create a separate repo for the IC-6600 project (alternative A) that installs arch-config as the base without changing it and adds everything the statement asks for on top: the nine Capa 2 themes, the Capa 3 commands with an ad- prefix, a PKGBUILD for our own package, scripts that measure each theme and save the evidence, and the docs. It has to be testable in a QEMU VM and install.sh has to be idempotent." |
| Result | Layered installer, C commands reading /proc and /sys, PKGBUILD, unit files, hook, udev rule, nftables, sudoers, experiments and docs |
| Validated / fixed / discarded | Validated by building and running on the author's laptop: C unit tests, package build with makepkg, ad-ipc safe vs --unsafe, SIGTERM shutdown, scheduler pilot. Entries 3 to 8 are the errors caught while doing so |
| How it was validated | `tests/run.sh`, `makepkg -f`, direct runs of each command |

### 2 · Trimming arch-config to the desktop

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | `lib/step-base.sh`, `config/base-skip-pacman.txt`, `config/base-skip-aur.txt` |
| Purpose | Install only the desktop part of arch-config. The rest of it is the author's development setup, makes the VM install take much longer, needs a bigger disk and adds nothing to any theme |
| Query (prompt) | "arch-config installs my whole work setup: docker, JDKs, node, postgres, LibreOffice, wine, TeX, VS Code, IntelliJ, Packet Tracer, nvm, pnpm, Go. None of that is needed for the project and it makes the VM install very slow. Keep only what the desktop needs to start, drop the rest from the pacman and AUR lists and skip the nvm / pnpm / Claude Code / Go part of its installer. Do it on a temporary copy, arch-config itself must not change." |
| Result | Two skip lists applied to a staged copy of arch-config: development, office, media and TeX packages plus GRUB (the distro boots with systemd-boot), every AUR package except `brave-bin` and `ttf-ms-fonts`, and the nvm / pnpm / Claude Code / Go section of its installer |
| Validated / fixed / discarded | **Validated.** We reviewed each list by hand and kept what the desktop needs to start (bspwm, sxhkd, alacritty, lemonbar, fonts, PipeWire, NetworkManager). `~/arch-config` stays identical to its remote |
| How it was validated | `tests/run.sh` checks the staged lists. Full `install.sh` on a clean VM, then `git -C ~/arch-config status` clean and the desktop starting with `startx` |

### 3 · AI error: signal sent to the whole process group

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | Theme 5, `src/ad-ipc/main.c` |
| Purpose | Forward SIGTERM from the parent to the producer and consumers |
| Query (prompt) | None of its own. The error was in the code generated in entry 1 and was found while testing it |
| Result | `kill(0, SIGTERM)` to forward the signal |
| Validated / fixed / discarded | **Fixed.** `kill(0, ...)` signals the whole process group, which also contains the shell or script that launched `ad-ipc`, so the caller died too (the `echo rc=$?` after the run never printed). Replaced by a list of child PIDs and `kill()` on each |
| How it was validated | Ran `(ad-ipc ...; echo rc=$?) &`, sent SIGTERM: before the fix nothing printed. After it, `rc=130`, no zombies (`ps -eo stat`), nothing left in `/dev/shm`. kill(2) man page: pid 0 = every process in the caller's process group |

### 4 · AI error: Makefile used the system `cc` instead of gcc

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | `src/Makefile` |
| Purpose | Build the C commands |
| Query (prompt) | None of its own. The error was in the code generated in entry 1 and was found while testing it |
| Result | `CC ?= gcc` |
| Validated / fixed / discarded | **Fixed.** `?=` never applies to `CC` because make already defines it as `cc`. On the author's machine `cc` resolved to an unrelated script in `~/bin` and the build failed with "cc: no such file: -O2". Replaced by `ifeq ($(origin CC),default)` |
| How it was validated | `make` before and after. GNU make manual, "Variables Used by Implicit Rules" |

### 5 · AI error: wrong column when parsing ad-ps output

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | Theme 1, `experiments/exp-01-sched.sh` |
| Purpose | Read the CPU% of each process from `ad-ps` |
| Query (prompt) | None of its own. The error was in the code generated in entry 1 and was found while testing it |
| Result | `awk '{print $9}'` |
| Validated / fixed / discarded | **Fixed.** CPU% is column 8. Column 9 is the command name. Also `$(spin ...)` started the busy loop in the background without redirecting its output, so the command substitution would wait forever. Both fixed |
| How it was validated | Pilot run with 3 s windows: nice 0/5 gave 0.755 vs 0.753 expected |

### 6 · AI error: race demo could hang forever

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | Theme 5, `src/ad-ipc/ring.c` |
| Purpose | `--unsafe` mode that shows the race condition |
| Query (prompt) | None of its own. The error was in the code generated in entry 1 and was found while testing it |
| Result | Consumers blocked in `sem_wait(full)` until a poison pill arrives |
| Validated / fixed / discarded | **Fixed.** Without the mutex two consumers can read the same slot and skip another. If the skipped slot holds a poison pill, a consumer never gets one and blocks forever. Changed to `sem_timedwait` plus a `producer_done` flag. Also, comparing counts alone hides the race when one item is lost and another duplicated, so the producer now sums `st_size` and the parent compares bytes |
| How it was validated | 3 `--unsafe` runs: all ended, all with exit 3 and bytes ≠ expected bytes. Safe run: exact match |

### 7 · AI error: makepkg produced two packages

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | Theme 6, `pacman/PKGBUILD`, `lib/step-tools.sh` |
| Purpose | Build the own package and install it |
| Query (prompt) | None of its own. The error was in the code generated in entry 1 and was found while testing it |
| Result | PKGBUILD without `options` |
| Validated / fixed / discarded | **Fixed.** Arch's default `makepkg.conf` enables `debug`, so a second `-debug` package is created and `makepkg --packagelist \| head -n1` could pick the wrong one. Added `options=('!debug')` |
| How it was validated | `makepkg -f` before and after, `makepkg --packagelist`, `tar -tf` of the package |

### 8 · AI error: package list included smem

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | `config/pkglist.txt`, `experiments/exp-00-dewm.sh` |
| Purpose | Measure the PSS of the desktop session for the DE/WM comparison |
| Query (prompt) | None of its own. The error was in the code generated in entry 1 and was found while testing it |
| Result | `smem` added to the package list |
| Validated / fixed / discarded | **Fixed.** smem is no longer in the official repositories, so pacman aborted the packages step and every later step (tools, security, services) never ran. Dropped smem. The experiment now sums the `Pss` line of `/proc/<pid>/smaps_rollup` |
| How it was validated | `pacman -Si smem` fails. Full `install.sh` run reaching the services step. PSS totals checked against a manual sum for two processes |

### 9 · Reading the service limits from the cgroup

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Magdaleno Gómez Díaz |
| Tool | ChatGPT |
| Component | Theme 4, `bin/ad-svc` |
| Purpose | Show the real limits and counters of a unit, not only what the unit file says |
| Query (prompt) | "I am writing ad-svc, a command that shows the limits of a systemd service. I set CPUQuota=20% and MemoryMax=64M on ad-monitor.service. Which cgroup v2 files do I read to see those limits and how much the service is actually using, and where do OOM kills show up?" |
| Result | Path `/sys/fs/cgroup/system.slice/<unit>/` with `cpu.max`, `cpu.stat`, `memory.max`, `memory.current` and `memory.events` |
| Validated / fixed / discarded | **Fixed.** After the OOM test `memory.events` showed `oom_kill 0`, although the journal had the kill. The answer did not mention that every restart creates a new cgroup with its counters at zero. `ad-svc` now labels the value "(since last start)" and prints the last journal lines next to it |
| How it was validated | `CPUQuota=20%` shows up as `cpu.max = 20000 100000`. OOM kill visible in `journalctl -u ad-monitor` and gone from `memory.events` after the restart |

### 10 · AI suggestion discarded: snapper rollback for undo

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Magdaleno Gómez Díaz |
| Tool | ChatGPT |
| Component | Theme 3, `bin/ad-snap` |
| Purpose | Restore a few deleted or corrupted files from a snapshot |
| Query (prompt) | "snapper takes hourly snapshots of / on btrfs. I deleted two config files and broke a third. How do I get back only those files from a snapshot without restoring the whole system?" |
| Result | `snapper rollback N` |
| Validated / fixed / discarded | **Discarded.** rollback replaces the whole root: it creates a new read-write snapshot, makes it the default subvolume and needs a reboot. To bring back three files that is far too much. `ad-snap undo A B` uses `snapper undochange A..B`, which only reverts the files that changed between the two snapshots |
| How it was validated | snapper(8) man page. Recovery demo of exp-03: two files deleted and one corrupted, `ad-snap diff 8 9` lists exactly those three and `ad-snap undo 8 9` restores them, in all four runs |

### 11 · AI error: hook ran before the transaction

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Magdaleno Gómez Díaz |
| Tool | ChatGPT |
| Component | Theme 6, `pacman/hooks/ad-pacnew.hook` |
| Purpose | List pending `.pacnew` and `.pacsave` files after every transaction |
| Query (prompt) | "Write a pacman hook for our package that runs on every install, upgrade or removal, lists the .pacnew and .pacsave files left in /etc and writes the names of the packages in the transaction to a log." |
| Result | Hook with `When = PreTransaction` |
| Validated / fixed / discarded | **Fixed.** pacman creates the `.pacnew` files while it installs, so a hook that runs before the transaction never sees the ones from that same transaction. Changed to `When = PostTransaction`. Kept `NeedsTargets` so pacman passes the package names on standard input for the log |
| How it was validated | alpm-hooks(5) man page. Reinstall of `pacman-contrib`: the hook ran fourth of four post-transaction hooks and wrote `transaction: 1 package(s): pacman-contrib` to its log |

### 12 · Why ad-monitor ended in start-limit-hit

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Magdaleno Gómez Díaz |
| Tool | ChatGPT |
| Component | Theme 4, `systemd/ad-monitor.service`, `experiments/exp-04-svc.sh` |
| Purpose | Understand why the SIGKILL test failed after the memory test |
| Query (prompt) | "ad-monitor.service has Restart=on-failure and MemoryMax=64M. In the experiment I make it run out of memory and then send it SIGKILL to check that it restarts. After the memory test it stays failed with start-limit-hit and never comes back. Why, if it is supposed to restart?" |
| Result | Explanation: systemd's default `OOMPolicy=stop` stops the whole unit after an OOM kill, which counts as a failure and triggers a restart. With the default limit of 5 starts in 60 s those restarts used up the budget |
| Validated / fixed / discarded | **Validated.** The behavior is the start limit doing its job, so we left the unit as it is. The experiment now calls `systemctl reset-failed` before each step |
| How it was validated | `systemctl show ad-monitor -p OOMPolicy -p StartLimitBurst -p StartLimitIntervalUSec`. systemd.service(5) and systemd.unit(5). Later runs: restart after SIGKILL in about 2 s |

### 13 · Bounded buffer with three semaphores

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jennifer López Miranda |
| Tool | Claude (claude.ai) |
| Component | Theme 5, `src/ad-ipc/ring.c` |
| Purpose | Understand the IPC design of `ad-ipc` well enough to explain and modify it in the defense |
| Query (prompt) | "In ad-ipc a producer puts file paths in a circular buffer in shared memory and several consumer processes take them. It uses three semaphores: empty, full and mutex. Explain what each one does and what exactly goes wrong if I remove the mutex, because I have to show it in the defense with the --unsafe flag." |
| Result | Explanation of each semaphore: `empty` counts free slots, `full` counts used slots, `mutex` makes reading and moving `tail` atomic. Without it two consumers can take the same slot |
| Validated / fixed / discarded | **Validated**, with one correction. The answer said that without the mutex the count of results would always be wrong. It is not: a lost item and a duplicated one cancel out in the count. That is why `ad-ipc` also compares bytes (see entry 6) |
| How it was validated | Bounded-buffer section of Silberschatz et al. (2018). Five runs with and five with `--unsafe`: one unsafe run gave exactly 3785 results with 11 MB missing |

### 14 · AI error: long job inside the udev rule

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jennifer López Miranda |
| Tool | Claude (claude.ai) |
| Component | Theme 8, `udev/90-ad-usb-storage.rules`, `systemd/ad-usb-event@.service` |
| Purpose | Log vendor, model, size and driver of every USB disk plugged in |
| Query (prompt) | "I need a udev rule that, when a USB storage device is connected, runs a script that reads the vendor, model, size and driver from sysfs and appends them to a log." |
| Result | Rule with `RUN+="/usr/lib/arch-distro/ad-usb-event.sh %k"` |
| Validated / fixed / discarded | **Fixed.** udev kills programs started with `RUN+=` after a short timeout and runs them in a sandbox, so it is meant for quick commands only. The rule now tags the device with `TAG+="systemd"` and `ENV{SYSTEMD_WANTS}`, and systemd starts `ad-usb-event@<device>.service`, which reads sysfs and writes the log. `RUN+=` stays only for the one-line `logger` call on removal |
| How it was validated | udev(7) man page. Hot-plug of a 64 MiB QEMU USB disk with `virsh attach-device --live`: the log shows `add /dev/sda vendor=QEMU model=QEMUHARDDISK size=64MiB driver=sd` |

### 15 · AI suggestion discarded: systemctl wildcard in sudoers

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jennifer López Miranda |
| Tool | Claude (claude.ai) |
| Component | Theme 9, `security/sudoers.d/arch-distro` |
| Purpose | Let the `operadores` group manage `ad-monitor.service` and nothing else |
| Query (prompt) | "Write a sudoers rule so the operadores group can start, stop and restart ad-monitor.service and read its journal, and nothing else as root." |
| Result | `%operadores ALL=(root) /usr/bin/systemctl * ad-monitor.service, /usr/bin/journalctl -u ad-monitor.service` |
| Validated / fixed / discarded | **Discarded.** The wildcard also allows `systemctl edit ad-monitor.service`, which opens an editor as root, and an editor can start a shell. `journalctl` without `--no-pager` opens `less`, where `!sh` gives a root shell. Replaced by exact commands (start, stop, restart) and `journalctl ... --no-pager` |
| How it was validated | `visudo -cf` before installing. exp-09: ana restarts the monitor but cannot run `systemctl edit` or restart sshd. `sudo -l -U ana` lists only the allowed commands |

### 16 · ACL entry that overrides the group

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jennifer López Miranda |
| Tool | Claude (claude.ai) |
| Component | Theme 9, `/srv/proyecto` setup in `lib/step-security.sh` |
| Purpose | Explain why beto cannot write in the shared directory although his group has `rwx` |
| Query (prompt) | "/srv/proyecto has the ACL g:proyecto:rwx and u:beto:r-x. beto is in the proyecto group, so why can he not create files there? I thought the group permission would add up with his user entry." |
| Result | Explanation of the ACL check order: owner, named users, groups, others. The first class that matches decides, so `user:beto:r-x` applies and the group entry is never checked |
| Validated / fixed / discarded | **Validated.** This is the behavior we wanted for the test, so the setup did not change |
| How it was validated | acl(5) man page. `getfacl /srv/proyecto` and exp-09: ana writes, beto gets "Permission denied" when writing and can list the files |

## Template for new entries

| Field | Content |
|-------|---------|
| Date · member | |
| Tool | |
| Component | |
| Purpose | |
| Query (prompt) | |
| Result | |
| Validated / fixed / discarded | |
| How it was validated | |

## Components built without AI

arch-config, the desktop base (bspwm, sxhkd, alacritty and lemonbar
configuration and its installer). It predates the project and this repository
only installs a trimmed copy of it.
