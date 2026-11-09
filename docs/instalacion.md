# Installation log: manual Arch Linux install (Capa 1)

This is the procedure every member follows by hand in their own VM. No
`archinstall` and no third-party scripts. Each step says **what** runs and
**why**. Device names assume a virtio disk (`/dev/vda`). On SATA/NVMe use the
name `lsblk` shows.

Target layout:

| Partition | Size | FS | Mount | Why |
|-----------|------|----|-------|-----|
| `/dev/vda1` | 1 GiB | FAT32 (ESP) | `/boot` | UEFI firmware can only read FAT. systemd-boot, the kernel and the initramfs live here |
| `/dev/vda2` | rest | btrfs | subvolumes below | copy-on-write root with snapshots (theme 3) |

| Subvolume | Mount | Why it is separate |
|-----------|-------|--------------------|
| `@` | `/` | the system. This is what snapper snapshots and what a rollback restores |
| `@home` | `/home` | a rollback of `/` must not undo user files |
| `@log` | `/var/log` | logs must survive a rollback so you can tell what went wrong |
| `@pkg` | `/var/cache/pacman/pkg` | the package cache is big and rebuildable, so keeping it out of snapshots saves space |
| `@swap` | `/swap` | a swap file cannot live in a subvolume that gets snapshotted |

## 0. Virtual machine

1. virt-manager → New VM → local ISO (archlinux-x86_64.iso), 2 vCPU, 4096 MiB RAM, 40 GiB disk.
2. Before finishing tick **Customize configuration** → Overview → Firmware:
   **UEFI x86_64 (OVMF_CODE.fd)**. Without this the VM boots in legacy BIOS and
   nothing about UEFI boot can be shown.
3. Take a snapshot before each risky step: partitioning, bootloader, first reboot.

## 1. Live environment

```sh
loadkeys la-latin1                      # Latin American keyboard in the console
cat /sys/firmware/efi/fw_platform_size  # must print 64: proves UEFI boot
ip link                                 # the VM NIC should be UP (DHCP from libvirt)
ping -c 3 archlinux.org                 # network works
timedatectl                             # NTP synced: package signatures check dates
```

If `fw_platform_size` does not exist the VM booted in BIOS mode. Go back to step 0.

## 2. Partitioning (GPT)

```sh
fdisk /dev/vda
#  g            new GPT table (UEFI needs GPT, MBR is for BIOS)
#  n, 1, ENTER, +1G   then  t, 1 (EFI System)
#  n, 2, ENTER, ENTER       (Linux filesystem by default)
#  w
lsblk /dev/vda
```

The ESP gets 1 GiB because each kernel + initramfs pair takes about 150 MiB
and the fallback images double it.

## 3. File systems and subvolumes

```sh
mkfs.fat -F 32 -n ESP /dev/vda1
mkfs.btrfs -L arch /dev/vda2
mount /dev/vda2 /mnt
for sv in @ @home @log @pkg @swap; do btrfs subvolume create /mnt/$sv; done
umount /mnt
```

Mount options: `noatime` avoids a metadata write on every read (with
copy-on-write that write would copy metadata blocks). `compress=zstd:1` is
cheap compression that also cuts the bytes written.

```sh
OPTS=noatime,compress=zstd:1
mount -o $OPTS,subvol=@ /dev/vda2 /mnt
mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,swap}
mount -o $OPTS,subvol=@home /dev/vda2 /mnt/home
mount -o $OPTS,subvol=@log  /dev/vda2 /mnt/var/log
mount -o $OPTS,subvol=@pkg  /dev/vda2 /mnt/var/cache/pacman/pkg
mount -o noatime,subvol=@swap /dev/vda2 /mnt/swap   # no compression for swap
mount -o fmask=0077,dmask=0077 /dev/vda1 /mnt/boot  # ESP readable by root only
```

## 4. Base system

```sh
pacstrap -K /mnt base linux linux-firmware btrfs-progs \
    sudo vim networkmanager git base-devel man-db man-pages
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
```

- `-K` creates a fresh pacman keyring inside the new system instead of copying the ISO's one.
- `base` is the minimal userland plus systemd as init. `linux` is the kernel.
  `linux-firmware` holds the device blobs. `btrfs-progs` is needed to manage the root fs.
- `genfstab -U` writes mounts by UUID, which does not change if disks get reordered.
  Check that every subvolume line keeps its `subvol=` option.

## 5. Inside the new system

```sh
arch-chroot /mnt
ln -sf /usr/share/zoneinfo/America/Costa_Rica /etc/localtime
hwclock --systohc                             # RTC in UTC, generates /etc/adjtime
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/; s/^#es_CR.UTF-8/es_CR.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=la-latin1' > /etc/vconsole.conf
echo 'arch-distro' > /etc/hostname
```

## 6. initramfs

The default `HOOKS` in `/etc/mkinitcpio.conf` already contain what a single
btrfs root needs (`udev`, `autodetect`, `microcode`, `modconf`, `kms`,
`keyboard`, `keymap`, `block`, `filesystems`). Remove `fsck` from `HOOKS`.
btrfs checks itself on mount and `fsck.btrfs` is a no-op.

```sh
vim /etc/mkinitcpio.conf   # remove fsck from HOOKS
mkinitcpio -P              # rebuild every preset (linux and linux-fallback)
```

## 7. Users

```sh
passwd                                   # root password
useradd -m -G wheel -s /bin/bash <user>  # wheel = may use sudo, and is allowed by sshd (theme 9)
passwd <user>
EDITOR=vim visudo                        # uncomment: %wheel ALL=(ALL:ALL) ALL
systemctl enable NetworkManager          # network on first boot
```

## 8. Boot loader (systemd-boot)

```sh
bootctl install          # copies systemd-boot to the ESP and adds an NVRAM boot entry
blkid -s UUID -o value /dev/vda2
```

`/boot/loader/loader.conf`:

```
default arch.conf
timeout 3
console-mode max
editor yes
```

`editor yes` allows editing the kernel line at the menu. That is what the
rescue/emergency target demo uses (theme 7). It is a security trade-off,
because anyone at the console can add `init=/bin/bash`. Document it and turn
it off after the defense.

`/boot/loader/entries/arch.conf`:

```
title   arch-distro
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=<uuid-of-vda2> rootflags=subvol=@ rw
```

`/boot/loader/entries/arch-fallback.conf`: same, with
`initrd /initramfs-linux-fallback.img`. The fallback image skips `autodetect`
and includes every module, so it boots even if the hardware changed.

```sh
exit
umount -R /mnt
reboot                    # remove the ISO from the VM first
```

## 9. First boot

```sh
nmcli device status                    # network up via NetworkManager
sudo pacman -Syu
git clone https://github.com/Jonathansl17/arch-distro.git
cd arch-distro
experiments/exp-00-capa1.sh <name>     # Capa 1 evidence -> logs/<name>/
./install.sh                           # log -> ~/.local/state/arch-distro/
cp ~/.local/state/arch-distro/install-*.log logs/<name>/
./install.sh                           # second run: idempotency proof
cp ~/.local/state/arch-distro/install-*.log logs/<name>/
reboot
```

## Known issues handled by install.sh

These come from reading arch-config's installer while building this repo.
They were not observed in a VM yet.

| Issue | Cause | How install.sh handles it |
|-------|-------|---------------------------|
| arch-config's `install.sh` would abort on a fresh VM | AUR `packettracer` needs the Cisco `.deb` downloaded by hand, and `set -e` stops everything | `step-base.sh` runs arch-config from a temp copy without that package |
| arch-config installs the author's whole dev setup (about 9 GB of official packages + IDEs from AUR) | it is a personal workstation config | the temp copy drops the packages in `config/base-skip-*.txt` and the nvm/pnpm/Claude/go section |
| ssh to the VM would be blocked after the base layer | arch-config enables ufw with default deny and no ssh rule | security step disables ufw and loads `security/nftables.conf` |

## Problems found and how we solved them

Each member adds a row for every problem hit during their own install.

| Who | Problem | Cause | Fix |
|-----|---------|-------|-----|
| | | | |
