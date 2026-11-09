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
experiments/exp-03-fs.sh        # about 25 min: 4 jobs × 2 FS × 3 repeats × 30 s
experiments/exp-03-rollback.sh  # live demo
```

- Same disk for both. ext4 is a 4 GiB loop image inside a NOCOW file
  (`chattr +C`), so btrfs CoW does not affect the ext4 numbers. The loop
  device still adds a layer, which is a known limitation.
- fio, `--direct=1 --ioengine=io_uring --iodepth=16 --size=1G --runtime=30
  --time_based`: `seqread`/`seqwrite` 1 MiB blocks, `randread`/`randwrite`
  4 KiB blocks. 3 repetitions.
- Values from fio terse output: KiB/s and IOPS.
- `--direct=1` skips the page cache, so the file system and the device are
  measured, not RAM.

## 4. Results

Pending (VM). Average of 3 runs from `results/tema-03/*/fio.csv`:

| Job | btrfs MiB/s | ext4 MiB/s | btrfs IOPS | ext4 IOPS |
|-----|-------------|------------|------------|-----------|
| seqread 1M | | | | |
| seqwrite 1M | | | | |
| randread 4K | | | | |
| randwrite 4K | | | | |

Rollback demo: paste `ad-snap diff` and the `ls -l` before/after from
`results/tema-03-rollback/*/demo.txt`.

## 5. Interpretation

Pending. Expected: similar sequential numbers. The 4 KiB random writes are
where btrfs should lose the most, because every write is CoW plus a metadata
update (and compression does not help with direct I/O). Explain any gap with
the CoW mechanism above. If the difference is small, consider the virtual
disk cache of the host (virtio `cache=` mode).
