# Theme 2: Memory · Owner: Jonathan Sancho Loaiza

## 1. What was implemented

- **zram** (`memory/zram-generator.conf` → `/etc/systemd/zram-generator.conf`):
  `zram0` sized at min(RAM/2, 4 GiB), zstd, `swap-priority = 100`.
- **Swap file** (`lib/step-memory.sh`): 2 GiB at `/swap/swapfile` on the
  `@swap` subvolume, created with `btrfs filesystem mkswapfile` (NOCOW, no
  compression, as swap on btrfs requires), priority 10 in `/etc/fstab`.
- **Priority rationale:** the kernel fills the higher-priority device first.
  Compressed RAM (zram, about 3:1 with zstd) is orders of magnitude faster
  than disk, so pages go there first, and the swap file only takes the
  overflow.
- `ad-mem` (`src/ad-mem/`, C): live RAM, swap, zram stored vs compressed size
  and ratio (`/sys/block/zram0/mm_stat`), system rates of `pgfault`,
  `pgmajfault`, `pswpin`, `pswpout` (`/proc/vmstat`) and the processes with
  the most minor/major faults per tick (`/proc/<pid>/stat` fields 10 and 12).
  `--csv` gives one row per tick for plots.
- `swappiness` stays at arch-config's value (10). See interpretation.

## 2. Operating systems concept

- Demand paging, page faults (minor vs major), swapping, page replacement and
  thrashing. Silberschatz et al. 10th ed., ch. 9 (Main Memory) and ch. 10
  (Virtual Memory). OSTEP ch. 21-22 (Beyond Physical Memory: mechanisms and policies).
- **Minor fault:** the page is already in RAM (page cache, zero page, shared)
  and only the page table entry is missing. **Major fault:** the page has to
  come from a block device. A page read back from zram also counts as major
  because it goes through the swap path, even though no disk I/O happens.
- **OOM killer:** when neither reclaim nor swap can free memory, the kernel
  kills the process with the highest `oom_score`.

## 3. Measurement method

```sh
experiments/exp-02-mem.sh
```

- Load: `stress-ng --vm 2 --vm-bytes 130% --vm-keep --timeout 60s`.
  stress-ng splits the percentage across the workers, so the total is 130%
  of the available memory (65% each).
- Sampling, both at 1 s: `vmstat -w 1` (si/so columns, KiB/s) and
  `ad-mem --csv -i 1000` (fault rates, zram ratio).
- Run 1 "with": zram (prio 100) + swap file (prio 10).
  Run 2 "without": `swapoff /dev/zram0`, swap file only. zram is restored afterwards.
- OOM: `dmesg | grep -i oom` after each run.
- Repetitions: 3 per configuration.

## 4. Results

Pending (VM). Table per run, average of 3:

| Config | Σ si (KiB/s·s) | Σ so | peak pgmajfault/s | zram ratio | stress-ng bogo ops/s | OOM kill? |
|--------|----------------|------|-------------------|------------|----------------------|-----------|
| with zram | | | | | | |
| without zram | | | | | | |

Plot suggestion: `swap_used_kib` and `pgmajfault_s` against time from both CSVs.

## 5. Interpretation

Pending. Questions to answer with the data:

- With zram, `so` should be high but `stress-ng` throughput should stay close
  to the no-pressure case, because "swap-out" is a compression in RAM. Without
  zram the same `so` hits the disk and throughput should drop (thrashing).
- Is the zram ratio high? The stress-ng pages are very repetitive, so the
  ratio will be much higher than with real data. Say so when comparing.
- Swappiness 10 tells the kernel to prefer dropping page cache over swapping
  anonymous pages. With zram the usual advice is a high value (100-180)
  because swap is cheap. Check whether the data supports changing it.
- If the OOM killer fired, which process did it pick and why (`oom_score`)?
