# Theme 3: File system · Owner: Magdaleno Gómez Díaz

## 1. What was implemented

- **btrfs root** with subvolumes `@`, `@home`, `@log`, `@pkg`, `@swap`
  ([installation log](instalacion.md#3-file-systems-and-subvolumes)), mounted
  with `noatime,compress=zstd:1`.
- **Automatic snapshots** (`lib/step-btrfs.sh`): snapper config `root` for
  `/`, timeline enabled (`snapper-timeline.timer`, hourly), kept 5 hourly and
  7 daily, plus `snapper-cleanup.timer` for retention.
- `ad-snap` (`bin/ad-snap`): `take`, `diff A B`, `undo A B`, `layout`.
- `experiments/exp-03-fs.sh` (fio benchmark) and `exp-03-rollback.sh` (live demo).

## 2. Operating systems concept

- File-system implementation, allocation, journaling vs copy-on-write.
  Silberschatz et al. 10th ed., ch. 13-15 (File-System Interface,
  Implementation, Internals). OSTEP ch. 40 (FS implementation), 42 (crash
  consistency and journaling), 43 (log-structured FS, the idea behind CoW).
- **ext4** updates blocks in place and protects metadata with a journal.
- **btrfs** never overwrites: a change writes new blocks and updates the
  B-tree up to the root. A snapshot is a new root pointing at the same tree,
  so it costs O(1) and shares every block until one side changes.
- Advantages: instant snapshots and rollback, checksums on data and metadata,
  transparent compression, subvolumes.
- Disadvantages: random overwrites fragment files (each rewrite moves the
  block), and fsync-heavy loads pay for the tree updates. Swap files and VM
  images need NOCOW.

## 3. Measurement method

```sh
experiments/exp-03-fs.sh        # about 13 min: 4 jobs × 2 FS × 3 repeats × 30 s
experiments/exp-03-rollback.sh  # live demo
```

- Same disk for both. ext4 is a 4 GiB loop image inside a NOCOW file
  (`chattr +C`), so btrfs CoW does not affect the ext4 numbers. The loop
  device still adds a layer, which is a known limitation.
- fio, `--direct=1 --ioengine=io_uring --iodepth=16 --size=1G --runtime=30
  --time_based`: `seqread`/`seqwrite` 1 MiB blocks, `randread`/`randwrite`
  4 KiB blocks. 3 repetitions per script run; the script ran twice in the
  VM (2026-11-09 19:02 and 19:22 UTC), so every value below averages 6.
- Values from fio terse output: KiB/s and IOPS.
- `--direct=1` skips the page cache, so the file system and the device are
  measured, not RAM.

## 4. Results

VM disk: qcow2 image on the host, virtio-blk, no `cache=` attribute in the
libvirt XML (QEMU default, writeback: the host page cache sits under the
guest disk). Root mount as measured: `btrfs rw,relatime,compress=zstd:3,
discard=async,space_cache=v2,subvol=/@`. ext4: `/dev/loop0` on
`/mnt/ad-ext4`. Raw data: `results/tema-03/<ts>/fio.csv`.

**fio, average of 6 repetitions (range of IOPS in brackets)**

| Job | btrfs MiB/s | ext4 MiB/s | btrfs IOPS | ext4 IOPS | ext4 / btrfs |
|-----|-------------|------------|------------|-----------|--------------|
| seqread 1M | 11 204 | 16 938 | 11 203 [9 831–11 750] | 16 937 [16 674–17 241] | 1.5× |
| seqwrite 1M | 403 | 3 434 | 403 [234–756] | 3 433 [2 783–3 813] | 8.5× |
| randread 4K | 283 | 753 | 72 363 [68 509–73 893] | 192 798 [188 885–194 793] | 2.7× |
| randwrite 4K | 43 | 179 | 11 098 [10 260–11 961] | 45 834 [33 232–52 851] | 4.1× |

**Rollback demo** (`results/tema-03-rollback/<ts>/demo.txt`, last run):

```text
$ ls -l /etc/arch-distro/rollback-demo        # before: alpha, beta, gamma (28, 27, 28 bytes)
# destructive change: delete alpha.conf and beta.conf, overwrite gamma.conf
$ ls -l /etc/arch-distro/rollback-demo        # after: only gamma.conf, 8 bytes
$ ad-snap diff 8 9
-..... /etc/arch-distro/rollback-demo/alpha.conf
-..... /etc/arch-distro/rollback-demo/beta.conf
c..... /etc/arch-distro/rollback-demo/gamma.conf
$ ad-snap undo 8 9
create:2 modify:1 delete:0
$ cat /etc/arch-distro/rollback-demo/gamma.conf
setting=gamma.conf original
```

The demo ran 4 times (one per `run-all.sh` pass) and restored the three
files every time.

## 5. Interpretation

- **The absolute numbers are not disk speed.** 11–17 GB/s of sequential
  reads is far above what the host SSD can do. `--direct=1` bypasses the
  guest's page cache, but the qcow2 image uses QEMU's default writeback
  cache, so reads are served from the host's RAM. The comparison between
  file systems is still meaningful for the work each one does per request,
  but not as a disk benchmark.
- **The ext4 side has an extra advantage.** It is a loop device created with
  `mount -o loop`, and loop devices do buffered I/O on their backing file by
  default. fio's O_DIRECT stops at the ext4 layer, then the loop driver goes
  through the guest page cache. That helps writes most, which fits the
  biggest gaps being in the write jobs (8.5× and 4.1×). Redoing the test
  with `losetup --direct-io=on`, or with a real partition, would remove this.
- **Where btrfs really pays.** Even with that caveat, the shape matches the
  theory. Random 4 KiB writes are the copy-on-write worst case: every block
  rewritten goes to a new location and the extent and checksum trees are
  updated up to the root. btrfs held about 11 k IOPS with little spread
  between runs, so that cost is steady. Sequential writes were slower and
  less stable on btrfs (234–756 IOPS): `compress=zstd:3` tries to compress
  fio's random data, which does not compress, so it spends CPU for nothing.
- **Reads cost less on both.** Reading does not trigger CoW, so the gap is
  smaller (1.5× sequential, 2.7× random). btrfs still checks the checksum of
  every block it reads.
- **What btrfs gives back.** The rollback demo is the reason to accept that
  cost on `/`: a snapper snapshot costs O(1) because it is only a new tree
  root, and `ad-snap undo` brought back two deleted files and one corrupted
  file in one command.
- **Configuration note.** The VM was installed with archinstall (allowed for
  testing, not for the final delivery), so its root mount options are
  archinstall's (`relatime`, `compress=zstd:3`) and not the ones in the
  installation log (`noatime`, `compress=zstd:1`). The numbers above come
  from the former.
