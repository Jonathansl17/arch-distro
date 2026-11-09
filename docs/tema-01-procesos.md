# Theme 1: Processes and scheduling · Owner: Jonathan Sancho Loaiza

## 1. What was implemented

- `ad-ps` (`src/ad-ps/`, C). Lists every process with PID, PPID, state,
  nice, policy (`SCHED_OTHER/BATCH/IDLE/FIFO/RR`), real-time priority, last
  core and CPU%. It reads `/proc/<pid>/stat` twice and divides the tick delta
  by the window length. `ad-ps nice PID N` calls `setpriority(2)` and
  `ad-ps policy PID fifo|rr|other|batch|idle [PRIO]` calls
  `sched_setscheduler(2)`.
- `ad-info` reports the fair scheduler in use. EEVDF on kernels ≥ 6.6, and
  it detects `sched_ext` if a BPF scheduler is loaded.
- `experiments/exp-01-sched.sh`: the experiment below.

## 2. Operating systems concept

- **CPU scheduling and process states.** Silberschatz, Galvin, Gagne,
  *Operating System Concepts* 10th ed., ch. 3 (Processes) and ch. 5 (CPU
  Scheduling: priority, real-time scheduling, the Linux example).
- **Proportional share.** Arpaci-Dusseau, *OSTEP*, ch. 9 (Proportional Share,
  section on the Linux CFS).
- **EEVDF** (Earliest Eligible Virtual Deadline First) replaced CFS in Linux
  6.6. Each runnable task has a weight from `sched_prio_to_weight[]`. Nice 0
  is 1024, and every nice step changes the weight by about 1.25×. The
  scheduler keeps each task's *lag* (CPU it is owed versus its ideal share).
  Among the eligible tasks (lag ≥ 0) it picks the one with the earliest
  virtual deadline (eligible time + slice / weight). Over time each task
  gets `weight / Σ weights` of the CPU, just like CFS. The difference is
  latency: a short slice gives an early deadline.
- **Real-time classes.** `SCHED_FIFO` and `SCHED_RR` always run before any
  fair task. Older kernels limited them with RT throttling
  (`sched_rt_runtime_us` out of `sched_rt_period_us`, 950 000 / 1 000 000).
  On the 7.2 kernel used here both values read 1 000 000, so that throttling
  is off. What keeps fair tasks alive is the fair deadline server
  (`fair_server`), a `SCHED_DEADLINE` reservation that runs fair tasks for
  50 ms out of every second when real-time tasks would starve them.

## 3. Measurement method

```sh
experiments/exp-01-sched.sh
```

- Part A: two busy loops (`bash -c 'while :; do :; done'`) pinned to core 0
  with `taskset -c 0`. Nice pairs: 0/0, 0/5, 0/10, 0/19, −5/5 (negative
  values via `sudo renice`). CPU% is measured with `ad-ps -p PID1 -p PID2
  -i 10000` (10 s window). Expected share = w1 / (w1 + w2).
- Part B: one loop switched to `SCHED_FIFO` priority 10 with
  `sudo chrt -f -p 10 PID` against one nice 0 loop on the same core, 10 s window.
- Repetitions: the script ran 4 times in the VM (4 separate `run-all.sh`
  passes, 18:42 to 19:19 UTC on 2026-11-09) and `shares.csv` is averaged.
- Note: `ad-info` shows `autogroup`. With autogroup on, tasks from different
  terminal sessions get grouped. Both loops start from the same script, so
  they share a group and the per-task weights apply.

## 4. Results

VM: Arch Linux, kernel 7.2.14-arch1-1, 6 vCPU, 7.6 GiB RAM, EEVDF with
autogroup on. 4 runs, 10 s window per pair. Raw data:
`results/tema-01/<ts>/shares.csv` and `rt.txt`.

**Part A: nice pairs on core 0 (average of 4 runs)**

| nice pair | CPU% task 1 | CPU% task 2 | measured share 1 | range over 4 runs | expected share 1 |
|-----------|-------------|-------------|------------------|-------------------|------------------|
| 0 / 0 | 49.8 | 49.8 | 0.500 | 0.500–0.501 | 0.500 |
| 0 / 5 | 75.1 | 24.5 | 0.754 | 0.753–0.754 | 0.753 |
| 0 / 10 | 90.1 | 9.6 | 0.904 | 0.904–0.904 | 0.903 |
| 0 / 19 | 98.3 | 1.4 | 0.986 | 0.986–0.986 | 0.986 |
| −5 / 5 | 90.1 | 9.6 | 0.904 | 0.904–0.904 | 0.903 |

Expected share uses the kernel weights: nice −5 = 3121, 0 = 1024,
5 = 335, 10 = 110, 19 = 15.

**Part B: SCHED_FIFO prio 10 against SCHED_OTHER nice 0 on core 0**

| run | CPU% SCHED_FIFO | CPU% SCHED_OTHER |
|-----|-----------------|------------------|
| 1 | 94.8 | 5.0 |
| 2 | 94.8 | 5.0 |
| 3 | 94.8 | 5.1 |
| 4 | 94.8 | 5.0 |

`sched_rt_runtime_us` = `sched_rt_period_us` = 1 000 000 in every run.

Pilot (author's laptop, Ryzen 5 7535HS, 3 s windows, 1 run) gave the same
picture: 0.500, 0.755 and 0.987 for 0/0, 0/5 and 0/19.

## 5. Interpretation

- The measured share matches `w1 / (w1 + w2)` within 0.001 in every pair,
  and the 4 runs agree with each other to 0.001. EEVDF hands out CPU in
  proportion to weight, as the theory says. The tiny excess over the
  expected value (0.904 vs 0.903) is the sampling: CPU% comes from
  `/proc/<pid>/stat` ticks, so each value is rounded to one tick (10 ms) over
  a 10 s window.
- −5/5 gives the same split as 0/10 (90.1 / 9.6). Only the ratio of the
  weights matters (3121/335 ≈ 1024/110 ≈ 9.3), not the absolute nice values.
  This is the multiplicative design of the weight table: each nice step is
  about ×1.25, so any two pairs 10 steps apart give the same ratio.
- nice 19 does not mean "never runs": the nice 19 task still gets 1.4%,
  because its weight (15) is small but not zero. EEVDF keeps its lag and it
  eventually becomes eligible.
- Part B: the FIFO task does not get 100%. Classic RT throttling is off
  (runtime = period), so the 5% left to the fair task comes from the fair
  deadline server, which reserves 50 ms per second for fair tasks: 50/1000 =
  5.0%, exactly what was measured. Without it a busy FIFO loop would starve
  every fair task on that core (including a shell trying to kill it).
- The VM adds little noise here: the vCPU is a host thread and host load
  could disturb it, but the 4 runs differ by at most 0.1 CPU%.
