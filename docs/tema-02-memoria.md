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
- OOM: kernel log lines `Killed process` since the start of each run
  (`journalctl -k --since @<start>`).
- Repetitions: 3 per configuration (3 `run-all.sh` passes in the VM,
  2026-11-09 18:49, 18:59 and 19:20 UTC).

## 4. Results

VM: 6 vCPU, 7.6 GiB RAM, zram0 3.8 GiB (zstd, prio 100), swap file 2 GiB
(prio 10), `vm.swappiness = 10`. Raw data: `results/tema-02/<ts>/`.

**Per run**

| run | config | memory asked / available | stress-ng bogo ops/s | Σ si (KiB/s·s) | Σ so (KiB/s·s) | peak pgmajfault/s | peak swap used | zram ratio | OOM kills |
|-----|--------|--------------------------|----------------------|----------------|----------------|-------------------|----------------|------------|-----------|
| 1 | with zram | 7.58 / 5.83 GB | 129 408 | 21.4 M | 22.1 M | 199 990 | 740 MiB | 2.98 | 0 |
| 1 | without | 9.42 / 7.24 GB | 3 413 | 5.8 M | 27.5 M | 27 027 | 2047 MiB | n/a | 12 |
| 2 | with zram | 8.74 / 6.73 GB | 84 696 | 29.3 M | 31.9 M | 237 793 | 2694 MiB | 2.61 | 0 |
| 2 | without | 9.49 / 7.31 GB | 2 677 | 3.8 M | 32.6 M | 22 610 | 2047 MiB | n/a | 12 |
| 3 | with zram | 8.68 / 6.68 GB | 12 294 | 35.3 M | 38.0 M | 271 882 | 2649 MiB | 2.68 | 0 |
| 3 | without | 9.34 / 7.20 GB | 3 720 | 5.0 M | 27.9 M | 22 521 | 2047 MiB | n/a | 21 |

**Average of 3 runs**

| config | bogo ops/s | Σ si | Σ so | peak pgmajfault/s | zram ratio | OOM kills per run |
|--------|------------|------|------|-------------------|------------|-------------------|
| with zram | 75 466 (12 294–129 408) | 28.6 M | 30.7 M | 236 555 | 2.76 | 0 |
| without zram | 3 270 (2 677–3 720) | 4.9 M | 29.3 M | 24 053 | n/a | 15 |

Note on the OOM column: runs 1 and 2 were taken before the OOM capture was
limited to each run's time window, so their files also contained kills from
earlier experiments of the same boot. The counts above keep only the kills
whose kernel timestamp falls inside that run. Run 3 already used the fixed
capture.

## 5. Interpretation

- **zram turns swapping into a RAM operation.** With zram the system swapped
  out about as much as without it (Σ so 30.7 M vs 29.3 M), yet read pages
  back about 6 times more (Σ si 28.6 M vs 4.9 M) and peaked at about 10 times
  more major faults per second. Those major faults are cheap: the page comes
  from compressed RAM, not from the virtual disk. Without zram the same
  faults wait for the swap file on btrfs, and stress-ng's throughput falls
  to 3.3 k ops/s, a classic thrashing curve.
- **Throughput with zram varies a lot (12 k to 129 k ops/s).** Run 1 asked
  only 1.75 GB beyond the available memory and peaked at 740 MiB of swap, so
  it fit almost entirely in zram. Runs 2 and 3 asked about 2 GB beyond it
  and used 2.6–2.7 GiB of swap. Run 3 spent 104 s of its 122 s CPU time in
  the kernel (stress-ng `sys` time), compressing and reclaiming. The
  difference is real but the cause between runs 2 and 3 is not isolated.
  The conclusion does not depend on it: even the worst zram run is 3.3 times
  faster than the best run without zram.
- **The OOM killer and capacity.** Without zram the only swap is the 2 GiB
  file, and every run filled it (peak 2047 MiB). Once RAM and swap are both
  full, reclaim fails and the kernel kills the stress-ng worker with the
  highest `oom_score` (the one with the most anonymous memory, between
  2.9 and 4.9 GB of RSS in the log). stress-ng restarts it, so the kill repeats
  12–21 times in 60 s. With zram the total swap is 3.8 + 2 GiB and no kill
  happened. So this comparison mixes two effects: zram is faster than disk
  swap, and it also adds capacity. A fairer speed-only test would give the
  "without" run a swap file the same size as zram.
- **The "without" run asked for more memory** (0.7 to 1.8 GB more), because
  `--vm-bytes 130%` is relative to the memory available when each run starts
  and swapping off zram frees some RAM. It makes that run somewhat harsher.
- **zram ratio 2.6–3.0.** stress-ng fills pages with patterns that zstd
  compresses well. Real workloads compress less, so the capacity gain would
  be smaller.
- **swappiness 10.** It tells the kernel to reclaim page cache before anonymous
  pages. Under this load there is almost no page cache to drop, so the
  kernel swapped anyway. With zram the usual advice is a high value (100 or
  more) because swapping to zram is cheap. These runs do not test that, so
  the value is left as arch-config sets it.
