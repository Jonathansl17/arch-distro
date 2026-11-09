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
  fair task. The only limit is RT throttling (`sched_rt_runtime_us` out of
  `sched_rt_period_us`, 950 000 / 1 000 000 by default). Recent kernels use
  a deadline server that reserves that 5% for fair tasks.

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
- Repetitions: run the script 3 times and average `shares.csv`.
- Note: `ad-info` shows `autogroup`. With autogroup on, tasks from different
  terminal sessions get grouped. Both loops start from the same script, so
  they share a group and the per-task weights apply.

## 4. Results

**Pilot run** (author's laptop, Ryzen 5 7535HS, kernel 7.2.14, 3 s windows,
1 repetition, not the VM):

| nice pair | CPU% task 1 | CPU% task 2 | measured share 1 | expected share 1 |
|-----------|-------------|-------------|------------------|------------------|
| 0 / 0 | 49.7 | 49.7 | 0.500 | 0.500 |
| 0 / 5 | 75.0 | 24.3 | 0.755 | 0.753 |
| 0 / 19 | 98.0 | 1.3 | 0.987 | 0.986 |

**VM run** (pending: 3 repetitions, 10 s windows, all 5 pairs + part B):

| nice pair | measured share 1 (avg) | expected share 1 |
|-----------|------------------------|------------------|
| 0 / 0 | | 0.500 |
| 0 / 5 | | 0.753 |
| 0 / 10 | | 0.903 |
| 0 / 19 | | 0.986 |
| −5 / 5 | | 0.903 |

| Part B | CPU% SCHED_FIFO | CPU% SCHED_OTHER |
|--------|-----------------|------------------|
| | | |

## 5. Interpretation

Pilot: the measured shares are within 0.002 of the weight ratio, which is
what proportional-share theory predicts. The small error comes from the
sampling window and from the measuring process itself running on the
machine.

To complete with the VM data:

- Does −5/5 give the same share as 0/10? It should, because only the weight
  ratio matters (3121/335 vs 1024/110).
- Part B: expect about 95% for the FIFO task and about 5% for the fair task
  (throttling / deadline server). If the fair task gets 0%, check
  `sched_rt_runtime_us`.
- In a VM the vCPU is itself a host thread, so host load can add noise.
