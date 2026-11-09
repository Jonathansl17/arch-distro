# Theme 5: Concurrency and IPC · Owner: Jennifer López Miranda

## 1. What was implemented

`ad-ipc` (`src/ad-ipc/`, C). It counts lines and bytes of every readable
file under a directory in parallel, like a multi-process `wc -l -c`.

| Process | Role |
|---------|------|
| parent | creates the IPC objects, forks, reads results, sums, reaps |
| producer (1) | walks the tree with `nftw` and pushes file paths into the ring |
| consumers (N, `-w`) | pop a path, count it, write `lines bytes path` to the pipe |

IPC mechanisms (4):

1. **POSIX shared memory** (`shm_open` + `ftruncate` + `mmap`): a ring buffer
   of 16 path slots shared by producer and consumers.
2. **Process-shared semaphores** in that memory (`sem_init(..., 1, ...)`):
   `empty` (free slots), `full` (filled slots) and `mutex` (head/tail). This
   is the classic bounded-buffer solution.
3. **Anonymous pipe** from consumers to parent. Each result line is a single
   `write` < `PIPE_BUF`, so lines from several consumers never interleave.
4. **Signals**. SIGTERM/SIGINT set a flag (handler without `SA_RESTART`, so a
   blocked `sem_wait` returns `EINTR` and the loop exits). The parent forwards
   SIGTERM to its own children by PID. SIGCHLD runs `waitpid(-1, WNOHANG)` in
   a loop, so there are no zombies. The shared memory is unlinked on exit.

End of work: one empty path per consumer (poison pill). `--unsafe` turns
the mutex off and adds a `sched_yield()` inside the critical section to show
the race. Exit codes: 0 ok, 3 counts disagree, 130 terminated.

## 2. Operating systems concept

- Process creation, IPC (shared memory vs message passing), the
  producer-consumer / bounded-buffer problem, semaphores, race conditions,
  critical sections, signals and zombies. Silberschatz et al. 10th ed., ch. 3
  (Processes, IPC, pipes), ch. 6 (Synchronization Tools) and ch. 7
  (Synchronization Examples, bounded buffer). OSTEP ch. 31 (Semaphores).

## 3. Measurement method

```sh
experiments/exp-05-ipc.sh
```

1. `strace -f -tt -e trace=clone,clone3,pipe2,openat,ftruncate,mmap,futex,kill,wait4,...`
   of one run on `/usr/share/doc` with 4 consumers.
2. Race: 5 runs with the mutex and 5 with `--unsafe`. Compare `results` vs
   `files` and `bytes` vs `expected_bytes` (the producer sums `st_size`).
   Bytes catch the case where one path is lost and another duplicated, which
   leaves the count unchanged.
3. SIGTERM after 2 s of a slow run (`-s 40`): `ps` of the children before,
   exit code, zombie count and `/dev/shm` after.

## 4. Results

**Pilot** (author's laptop, `/usr/share/doc`, 4 consumers):

| Mode | files | results | bytes | expected bytes | exit |
|------|-------|---------|-------|----------------|------|
| mutex | 15777 | 15777 | 297612836 | 297612836 | 0 |
| --unsafe #1 | 15777 | 15775 | 296109991 | 297612836 | 3 |
| --unsafe #2 | 15777 | 15779 | 290914103 | 297612836 | 3 |
| --unsafe #3 | 15777 | 15763 | 298514214 | 297612836 | 3 |

SIGTERM pilot: exit 130, 0 zombies, 0 `ad-ipc` objects in `/dev/shm`.

**VM run**: pending, same tables from `results/tema-05/`. Add the key strace
lines (`clone` × 5, `pipe2`, `openat(/dev/shm/ad-ipc-*)`, `kill`, `wait4`)
with one sentence each.

## 5. Interpretation

Pilot: with the mutex every path is consumed exactly once. Without it two
consumers can read the same `tail` before either advances it. One slot is
then processed twice and the next one never. Results can be fewer (lost
paths) or more (duplicates beat the losses) than the files, and the byte sum
is off in both directions, which proves both effects happen. The semaphores
`full`/`empty` alone are not enough: they count slots but do not make the
read-modify-write of `tail` atomic.
