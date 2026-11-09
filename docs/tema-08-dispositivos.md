# Theme 8: I/O and devices · Owner: Jennifer López Miranda

## 1. What was implemented

- **Module blacklist** (`modprobe/ad-blacklist.conf` →
  `/usr/lib/modprobe.d/`). `pcspkr` (PC speaker beep, no use in a VM or
  laptop) and `joydev` (legacy `/dev/input/js*`, everything modern uses
  evdev). `blacklist` stops automatic loading by alias (udev). An explicit
  `modprobe pcspkr` still works.
- **Own udev rule** (`udev/90-ad-usb-storage.rules`). When a USB disk
  appears (`SUBSYSTEM=="block"`, `ID_BUS=="usb"`, `DEVTYPE=="disk"`) it asks
  systemd to start `ad-usb-event@<kernel name>.service` through
  `SYSTEMD_WANTS`. udev kills long `RUN+=` programs, so the work goes to a
  unit. The unit runs `ad-usb-event.sh`, which reads vendor, model, size and
  driver from sysfs and appends to `/var/log/arch-distro/usb-events.log`. On
  removal the rule logs to the journal with `logger`.
- `ad-dev` (`bin/ad-dev`): PCI devices with the bound driver (sysfs
  `driver` symlink), top interrupt lines, `irqdiff CMD` (per-IRQ delta while
  a command runs), `mod NAME` (modinfo + refcount from `/proc/modules`), `usb`.
- `ad-info` shows GPU and NPU (PCI class 0x03 and 0x12) with their driver.

## 2. Operating systems concept

- I/O hardware, interrupts, device drivers, kernel I/O subsystem.
  Silberschatz et al. 10th ed., ch. 12 (I/O Systems). OSTEP ch. 36 (I/O devices).
- The kernel exposes devices through **sysfs** (`/sys/bus/pci/devices/*`:
  class, vendor, device, driver), loads drivers as **modules** matched by
  `modalias`, and **udev** reacts to the kernel's uevents (netlink) to create
  `/dev` nodes and run rules.
- **GPU/NPU (Unit 1):** in the VM the GPU is a virtual device (`virtio-gpu`
  → `virtio_gpu` DRM driver, or QXL → `qxl`). On the host the drivers are
  `amdgpu` and `nvidia`. No NPU is present (no class 0x12 device), and
  `ad-info` says so. On machines with one, the driver would be `amdxdna` or
  `intel_vpu`, exposed under `/sys/class/accel`. The driver is what turns
  the device into kernel interfaces (DRM, accel) that user space can use.

## 3. Measurement method

```sh
experiments/exp-08-dev.sh     # plug a USB stick when asked (virt-manager: Add Hardware > USB Host Device)
```

1. `lsmod`, `modinfo dummy`, `modprobe dummy` (creates `dummy0`), `modprobe -r dummy`.
2. `modprobe --showconfig | grep blacklist`, `lsmod` shows the blacklisted modules are not loaded.
3. `lspci -k` and `ad-info`.
4. `ad-dev irqdiff dd if=/dev/zero of=/var/tmp/ad-io-test bs=1M count=1024 oflag=direct`.
5. `udevadm monitor --udev --kernel --subsystem-match=block` for 30 s while
   plugging, then `dmesg` and `ad-dev usb`.

## 4. Results

Pending (VM). Paste the `irqdiff` table (expect the virtio-blk / NVMe queue
IRQs at the top), `lspci -k` lines for the GPU, the udev monitor events
(KERNEL then UDEV, add for sdX and sdX1) and the usb-events.log line.

## 5. Interpretation

Pending. Explain which IRQ lines grew during `dd` and why (one completion
interrupt per request, MSI-X per queue). Explain why KERNEL events come before
UDEV events in the monitor. Explain the role of `virtio_gpu` versus a real GPU
driver.
