# arch-distro

A personal Arch Linux distribution built for IC-6600 Principios de Sistemas
Operativos (TEC, San Carlos, II semester 2026), alternative A.

It is built in two layers:

1. **Base: [arch-config](https://github.com/Jonathansl17/arch-config)**, the
   author's daily desktop. It installs bspwm + sxhkd, alacritty, lemonbar,
   PipeWire, NetworkManager and the dotfiles. This repo never edits
   arch-config. `install.sh` clones it and runs its installer from a
   temporary copy (see [Base layer](#base-layer)).
2. **This repo** adds the operating-systems work: the 9 Capa 2 themes, the
   custom commands of Capa 3, measurement scripts and all the documentation.

Team: Jonathan Sancho Loaiza, Magdaleno Gómez Díaz, Jennifer López Miranda.
Professor: Jorge Alfaro Velasco.

## Requirements

- A **manual** Arch Linux install booted in **UEFI** mode, following
  [docs/instalacion.md](docs/instalacion.md). It uses a btrfs root, systemd-boot,
  a user in `wheel` with sudo, and a working network.
- Suggested VM: 2 vCPU, 4 GB RAM, 30 GB disk (QEMU/KVM + virt-manager).
  arch-config's AUR list is large, so 40 GB is safer.

## Install

```sh
sudo pacman -S --needed git
git clone https://github.com/Jonathansl17/arch-distro.git
cd arch-distro
./install.sh            # base + every layer, logs to ~/.local/state/arch-distro/
reboot
```

| Flag | Effect |
|------|--------|
| *(none)* | base (arch-config) + packages, memory, btrfs, tools, security, services |
| `--skip-base` | only the arch-distro layers, for when the desktop is already set up |
| `--only STEP` | one step: `base packages memory btrfs tools security services` |

Every step checks the current state before acting, so a second run changes
nothing. That is the idempotency requirement. One exception: when the base
layer runs, arch-config turns ufw back on and the security step turns it off
again, so that pair repeats on every full run. Copy your install log to
`logs/<your-name>/` for the evidence.

### Base layer

`lib/step-base.sh` clones arch-config to `~/arch-config` if it is missing,
copies it to a temp dir and trims that copy down to the desktop:

- [config/base-skip-pacman.txt](config/base-skip-pacman.txt) drops the
  development, office, media and TeX packages (docker, JDKs, node, postgres,
  libreoffice, wine, texlive...) and GRUB (this distro boots with systemd-boot).
- [config/base-skip-aur.txt](config/base-skip-aur.txt) drops every AUR
  package except `brave-bin` and `ttf-ms-fonts` (VS Code, IntelliJ, pgAdmin,
  Postman, Packet Tracer...).
- The nvm / pnpm / Claude Code / go section of arch-config's installer is
  removed from the copy. Without `python-pipx`, its pipx tools are skipped too.

What stays: Xorg, bspwm, sxhkd, alacritty, lemonbar, slock, PipeWire,
NetworkManager, Bluetooth, fonts, pcmanfm, neovim, Brave and the dotfiles.
Then the copy's `install.sh` runs. arch-config enables ufw, and the security
step replaces it with native nftables (theme 9).

## What gets installed

| Piece | Where it lives in the repo | Installed as |
|-------|----------------------------|--------------|
| C commands `ad-info`, `ad-ps`, `ad-mem`, `ad-ipc` | `src/` | package `arch-distro-tools` (`pacman/PKGBUILD`) |
| Shell commands `ad-svc`, `ad-pkg`, `ad-dev`, `ad-snap`, `ad-boot`, `ad-sec` | `bin/` | same package |
| `ad-monitor.service`, `ad-report.service` + `.timer`, `ad-usb-event@.service` | `systemd/` | same package |
| ALPM hook `ad-pacnew.hook` | `pacman/hooks/` | same package |
| udev rule `90-ad-usb-storage.rules` | `udev/` | same package |
| Module blacklist | `modprobe/` | same package |
| zram + swap file | `memory/`, `lib/step-memory.sh` | `/etc/systemd/zram-generator.conf`, `/swap/swapfile` |
| snapper timeline snapshots | `lib/step-btrfs.sh` | snapper config `root` |
| nftables, sudoers, sshd, ACL | `security/`, `lib/step-security.sh` | `/etc/...` |

Everything that can be packaged is packaged, so `pacman -Ql arch-distro-tools`
lists it and `pacman -R arch-distro-tools` removes it cleanly.

## Commands (Capa 3)

| Command | What it does | OS interface | Theme | Author |
|---------|--------------|--------------|-------|--------|
| `ad-info` | **Mandatory.** Kernel, uptime, scheduler, CPU, GPU/NPU + driver, memory/swap/zram, processes, root fs | `/proc`, `/sys/bus/pci`, `uname`, `statvfs` | all | team |
| `ad-ps` | Process table (PID, PPID, state, nice, policy, CPU%), changes nice and policy | `/proc/<pid>/stat`, `setpriority`, `sched_setscheduler` | 1 | Jonathan |
| `ad-mem` | Live RAM, swap, zram ratio, fault and swap rates, top faulting processes, CSV mode | `/proc/meminfo`, `/proc/vmstat`, `/sys/block/zram0` | 2 | Jonathan |
| `ad-snap` | btrfs snapshots: take, diff, rollback, layout | snapper, btrfs ioctls | 3 | Magdaleno |
| `ad-svc` | cgroup limits and live usage of a unit, provoked crash | `/sys/fs/cgroup`, systemd, signals | 4 | Magdaleno |
| `ad-ipc` | Parallel `wc` with producer/consumer over shared memory + pipe | `shm_open`, semaphores, pipes, signals | 5 | Jennifer |
| `ad-pkg` | pacman local db, hooks, dependency trees, transactions | `/var/lib/pacman/local`, ALPM | 6 | Magdaleno |
| `ad-boot` | Boot chain summary, blame, critical chain | `/sys/firmware/efi`, `/proc/cmdline`, systemd | 7 | Jonathan |
| `ad-dev` | PCI drivers, interrupt counts and deltas, module info, USB events | `/sys/bus/pci`, `/proc/interrupts`, `/proc/modules` | 8 | Jennifer |
| `ad-sec` | Firewall, listening ports, ssh, sudo rules, ACLs, auth failures | nftables, `sshd -T`, journal | 9 | Jennifer |

Each one prints its usage with `-h` or with an unknown subcommand.

## Keyboard shortcuts

See [docs/cheatsheet.md](docs/cheatsheet.md). They are arch-config's own
`sxhkdrc` keys, unmodified: the mandatory actions use its keys (`Ctrl + <`
terminal, `Ctrl + Q` close, `Super + N` desktops) and 3 existing shortcuts are
assigned to each member.

## Repository map

```
install.sh            bootstrap (idempotent), one function per step in lib/
config/               settings.sh (every tunable), pkglist.txt, services.txt
lib/                  installer steps + log/file helpers
src/                  C sources (common/, ad-info/, ad-ps/, ad-mem/, ad-ipc/, tests/)
bin/                  shell commands
systemd/              unit files + their scripts
pacman/               PKGBUILD + hooks/
udev/  modprobe/      device rules and module blacklist
memory/  security/    zram config, nftables, sudoers, sshd
experiments/          one script per theme, writes to results/ (git-ignored)
tests/run.sh          C unit tests, shell syntax, helpers, config validators
docs/                 installation log, responsibilities, AI log, cheatsheet, evidence sheets
logs/                 bootstrap logs of each member
```

## Tests

```sh
tests/run.sh
```

## Documentation

- [docs/instalacion.md](docs/instalacion.md): manual install, step by step, with the reason for each command
- [docs/de-wm.md](docs/de-wm.md): why bspwm, with measurements
- [docs/responsabilidades.md](docs/responsabilidades.md): who owns each theme
- [docs/bitacora_ia.md](docs/bitacora_ia.md): AI usage log
- [docs/cheatsheet.md](docs/cheatsheet.md): keyboard shortcuts
- `docs/tema-0N-*.md`: one evidence sheet per theme
