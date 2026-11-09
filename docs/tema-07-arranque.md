# Theme 7: Boot process · Owner: Jonathan Sancho Loaiza

## 1. What was implemented

- systemd-boot on a 1 GiB ESP with a normal and a fallback entry
  ([installation log](instalacion.md#8-boot-loader-systemd-boot)).
- `ad-boot` (`bin/ad-boot`). One screen per stage: UEFI firmware (bitness
  from `/sys/firmware/efi`), loader entry (`bootctl status`), kernel and
  `/proc/cmdline`, mkinitcpio `HOOKS`, default target and
  `systemd-analyze time`. Subcommands `blame`, `chain`, `boots`.
- `experiments/exp-07-boot.sh LABEL` stores, per boot, the stage times, blame,
  critical chain and `systemd-analyze plot` SVG. `summary` averages them by label.

## 2. Operating systems concept

Boot chain. Silberschatz et al. 10th ed., ch. 2 (2.9 Building and Booting an
Operating System).

1. **UEFI firmware** runs POST, reads the NVRAM boot entries and loads
   `systemd-bootx64.efi` from the FAT ESP.
2. **systemd-boot** shows the entries in `/boot/loader/entries` and loads
   `vmlinuz-linux` + `initramfs-linux.img` with the `options` command line.
3. **Kernel** decompresses itself, initialises memory, the scheduler and
   built-in drivers, unpacks the initramfs into a tmpfs and runs its `/init`.
4. **initramfs**: mkinitcpio hooks run in order. `udev` loads the storage
   modules (`autodetect` kept only those of this machine), `filesystems`
   brings btrfs, then the real root is mounted (`subvol=@`) and control
   switches to it.
5. **systemd** (PID 1) builds the dependency graph to `default.target`
   (`multi-user.target` here, getty on TTY1 then `startx` from
   `.bash_profile`). Units start in parallel. Ordering only comes from
   `After=`/`Before=`.

## 3. Measurement method

Stage times come from `systemd-analyze time`: firmware, loader, kernel,
initrd and userspace. Each value is the average of 3 boots per label.

```sh
experiments/exp-07-boot.sh before   # reboot, repeat ×3
# apply ONE optimization, for example:
#   /boot/loader/loader.conf: timeout 3 -> timeout 0 (menu skipped, hold space to show it)
#   or HOOKS: replace udev with systemd (and keymap/consolefont with sd-vconsole), mkinitcpio -P
#   or disable a slow unit that `ad-boot blame` shows at the top
experiments/exp-07-boot.sh after    # reboot, repeat ×3
experiments/exp-07-boot.sh summary
```

**Rescue demo (live).** At the systemd-boot menu press `e` (needs
`editor yes`), append `systemd.unit=rescue.target`, press Enter, give the root
password, run `systemctl list-units --type=target`. For
`systemd.unit=emergency.target` only `/` is mounted, read-only. Run `exit`
to continue to the default target.

## 4. Results

VM, UEFI (OVMF), systemd-boot. Kernel command line in every boot:
`root=PARTUUID=... zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs
console=uart,io,0x3f8 console=tty0`. Raw data: `results/tema-07/boots.csv`
and `results/tema-07/before/<ts>-{time,blame,chain,plot}`.

| Label | boot | firmware (s) | loader (s) | kernel (s) | initrd (s) | userspace (s) | total (s) |
|-------|------|--------------|------------|------------|------------|---------------|-----------|
| before | b8e3a775 | n/a | n/a | 1.571 | n/a | 1.711 | 3.283 |
| before | 8e5cb3a4 | n/a | n/a | 1.713 | n/a | 2.075 | 3.789 |
| before | 74c1b61a | n/a | n/a | 1.549 | n/a | 1.913 | 3.462 |
| **before, mean** | 3 | n/a | n/a | **1.611** | n/a | **1.900** | **3.511** |
| after | 1 | n/a | n/a | 1.214 | n/a | 1.874 | 3.088 |
| after | 2 | n/a | n/a | 1.187 | n/a | 1.951 | 3.138 |
| after | 3 | n/a | n/a | 1.233 | n/a | 1.902 | 3.135 |
| **after, mean** | 3 | n/a | n/a | **1.211** | n/a | **1.909** | **3.120** |

Optimization: `quiet` added and `console=uart,io,0x3f8` removed from the
kernel command line (no kernel messages printed to the emulated serial port).


**Blame, top 5** (last boot, 74c1b61a): `dev-vda2.device` 345 ms,
`ad-report.service` 238 ms, `systemd-udev-trigger.service` 170 ms,
`NetworkManager.service` 147 ms, `user@1000.service` 138 ms.

**Critical chain** (same boot):

```text
graphical.target @1.913s
└─multi-user.target @1.912s
  └─getty.target @1.912s
    └─serial-getty@ttyS0.service @1.912s
      └─systemd-user-sessions.service @1.899s +9ms
        └─network.target @1.890s
          └─NetworkManager.service @1.742s +147ms
            └─network-pre.target @1.741s
```

## 5. Interpretation

- **Missing stages.** `systemd-analyze` only printed kernel and userspace.
  Firmware and loader times come from EFI variables that the boot loader
  writes; this VM's boot did not provide them, so they are reported as n/a,
  not as 0. initrd is missing because the initramfs is built with the
  busybox `udev` hook, not the `systemd` hook. Without systemd inside the
  initramfs nobody records when it ended, so its time is counted inside
  "kernel".
- **Spread before optimizing.** Kernel varied between 1.549 and 1.713 s and
  userspace between 1.711 and 2.075 s across 3 boots. An "after" result has
  to move the mean by more than that spread (about 0.16 s and 0.36 s) to
  count as an improvement.
- **What the userspace numbers say.** `graphical.target` waits for
  `network.target`, which waits for NetworkManager (about 150 ms), so the
  network is on the critical path. `dev-vda2.device` (345 ms) is the time
  until udev announced the root disk. `ad-report.service` shows up in blame
  because its timer has `Persistent=true`: a run missed while the VM was off
  is caught up at boot. It is not on the critical chain, so it costs CPU
  during boot but does not delay the target.
- **The optimization targets the kernel stage**.
  Every kernel message was printed to an emulated 16550 serial port, which
  QEMU services one byte at a time, so a verbose kernel spends real time
  waiting on the console. With `quiet` and without the serial console the
  kernel stage drops from 1.611 to 1.211 s on average, a 0.40 s change, larger
  than the 0.16 s spread of the "before" boots. Userspace stays the same
  (1.900 vs 1.909 s, inside its 0.36 s spread), which is what should happen,
  since the change does not touch anything systemd runs. Total: 3.511 →
  3.120 s.
- Trade-off: without the serial console a kernel panic is no longer visible
  on `ttyS0`; it only shows on the graphical console.
