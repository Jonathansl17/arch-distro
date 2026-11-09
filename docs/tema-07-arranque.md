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

Pending (VM).

| Label | n | firmware (s) | loader (s) | kernel (s) | initrd (s) | userspace (s) |
|-------|---|--------------|------------|------------|------------|---------------|
| before | 3 | | | | | |
| after | 3 | | | | | |

Add `ad-boot blame` top 10 and the critical chain of one boot.

## 5. Interpretation

Pending. Name the stage the optimization targets and check that only that
column moved. Note: `loader` includes the menu timeout. In a VM, `firmware`
includes OVMF's own init and may vary between boots. Compare against the
spread of the 3 runs before claiming an improvement.
