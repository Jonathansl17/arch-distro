# AI usage log

Format from annex 3 of the statement. One entry per relevant query. Every
member logs their own entries for the themes they own. If a component was
built without AI, its owner says so in the last section.

## Entries

### 1

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | Whole repository (structure, install.sh, src/, bin/, systemd/, docs) |
| Purpose | Generate a first version of the repo on top of arch-config without modifying it |
| Summarized query | "Create another repo with everything needed to test in a VM, all themes included, without changing arch-config" |
| Result | Layered installer, C commands reading /proc and /sys, PKGBUILD, unit files, hook, udev rule, nftables, sudoers, experiments and docs |
| Validated / fixed / discarded | Validated by building and running on the author's laptop: C unit tests, package build with makepkg, ad-ipc safe vs --unsafe, SIGTERM shutdown, scheduler pilot. Entries 2 to 6 are the errors caught while doing so |
| How it was validated | `tests/run.sh`, `makepkg -f`, direct runs of each command |

### 2 · AI error: signal sent to the whole process group

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | Theme 5, `src/ad-ipc/main.c` |
| Purpose | Forward SIGTERM from the parent to the producer and consumers |
| Summarized query | Part of entry 1 |
| Result | `kill(0, SIGTERM)` to forward the signal |
| Validated / fixed / discarded | **Fixed.** `kill(0, ...)` signals the whole process group, which also contains the shell or script that launched `ad-ipc`, so the caller died too (the `echo rc=$?` after the run never printed). Replaced by a list of child PIDs and `kill()` on each |
| How it was validated | Ran `(ad-ipc ...; echo rc=$?) &`, sent SIGTERM: before the fix nothing printed. After it, `rc=130`, no zombies (`ps -eo stat`), nothing left in `/dev/shm`. kill(2) man page: pid 0 = every process in the caller's process group |

### 3 · AI error: Makefile used the system `cc` instead of gcc

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | `src/Makefile` |
| Purpose | Build the C commands |
| Summarized query | Part of entry 1 |
| Result | `CC ?= gcc` |
| Validated / fixed / discarded | **Fixed.** `?=` never applies to `CC` because make already defines it as `cc`. On the author's machine `cc` resolved to an unrelated script in `~/bin` and the build failed with "cc: no such file: -O2". Replaced by `ifeq ($(origin CC),default)` |
| How it was validated | `make` before and after. GNU make manual, "Variables Used by Implicit Rules" |

### 4 · AI error: wrong column when parsing ad-ps output

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | Theme 1, `experiments/exp-01-sched.sh` |
| Purpose | Read the CPU% of each process from `ad-ps` |
| Summarized query | Part of entry 1 |
| Result | `awk '{print $9}'` |
| Validated / fixed / discarded | **Fixed.** CPU% is column 8. Column 9 is the command name. Also `$(spin ...)` started the busy loop in the background without redirecting its output, so the command substitution would wait forever. Both fixed |
| How it was validated | Pilot run with 3 s windows: nice 0/5 gave 0.755 vs 0.753 expected |

### 5 · AI error: race demo could hang forever

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | Theme 5, `src/ad-ipc/ring.c` |
| Purpose | `--unsafe` mode that shows the race condition |
| Summarized query | Part of entry 1 |
| Result | Consumers blocked in `sem_wait(full)` until a poison pill arrives |
| Validated / fixed / discarded | **Fixed.** Without the mutex two consumers can read the same slot and skip another. If the skipped slot holds a poison pill, a consumer never gets one and blocks forever. Changed to `sem_timedwait` plus a `producer_done` flag. Also, comparing counts alone hides the race when one item is lost and another duplicated, so the producer now sums `st_size` and the parent compares bytes |
| How it was validated | 3 `--unsafe` runs: all ended, all with exit 3 and bytes ≠ expected bytes. Safe run: exact match |

### 6 · AI error: makepkg produced two packages

| Field | Content |
|-------|---------|
| Date · member | 2026-11-09 · Jonathan Sancho Loaiza |
| Tool | Claude Code (Claude Opus 5.5) |
| Component | Theme 6, `pacman/PKGBUILD`, `lib/step-tools.sh` |
| Purpose | Build the own package and install it |
| Summarized query | Part of entry 1 |
| Result | PKGBUILD without `options` |
| Validated / fixed / discarded | **Fixed.** Arch's default `makepkg.conf` enables `debug`, so a second `-debug` package is created and `makepkg --packagelist \| head -n1` could pick the wrong one. Added `options=('!debug')` |
| How it was validated | `makepkg -f` before and after, `makepkg --packagelist`, `tar -tf` of the package |

## Template for new entries

| Field | Content |
|-------|---------|
| Date · member | |
| Tool | |
| Component | |
| Purpose | |
| Summarized query | |
| Result | |
| Validated / fixed / discarded | |
| How it was validated | |

## Components built without AI

None so far.
