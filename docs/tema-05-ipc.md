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

**VM run** (2026-11-09 19:35 UTC, `/usr/share/doc`, 4 consumers, raw data in
`results/tema-05/<ts>/`):

| Mode | run | files | results | bytes | expected bytes | exit |
|------|-----|-------|---------|-------|----------------|------|
| mutex | 1–5 | 3785 | 3785 | 102 899 712 | 102 899 712 | 0 (all 5) |
| --unsafe | 1 | 3785 | 3787 | 99 946 560 | 102 899 712 | 3 |
| --unsafe | 2 | 3785 | 3785 | 91 707 330 | 102 899 712 | 3 |
| --unsafe | 3 | 3785 | 3783 | 78 648 894 | 102 899 712 | 3 |
| --unsafe | 4 | 3785 | 3789 | 92 109 859 | 102 899 712 | 3 |
| --unsafe | 5 | 3785 | 3781 | 87 923 869 | 102 899 712 | 3 |

The same test ran in 2 earlier passes of `run-all.sh` (18:55 and 19:16 UTC)
with the same outcome: across the 3 passes the mutex mode was exact in 15 of
15 runs and `--unsafe` was wrong in 15 of 15. A first pass at 18:29 UTC is
left out: the mutex runs were exact again, but 4 of its 5 `--unsafe` runs
ended with exit 130 (stopped by a signal) and the log does not say what sent
it.

**SIGTERM after 2 s** (slow run, `-s 40`): `ps --ppid` showed the 4
consumers before the signal; then `exit=130`, `zombies=0`, `shm_left=0`
(no `ad-ipc-*` left in `/dev/shm`). The run stopped after 200 of 220 files.

**strace -f, key lines** (`1-strace-key.txt`, PID 8929 = parent):

```text
8929 openat(AT_FDCWD, "/dev/shm/ad-ipc-8929", O_RDWR|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC, 0600) = 3
8929 ftruncate(3, 4240) = 0
8929 pipe2([3, 4], 0) = 0
8929 clone(... flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD ...) = 8930   (x5)
8932 openat(AT_FDCWD, "/usr/share/doc/.../libopenmpt_example_c_pipe.c", O_RDONLY|O_CLOEXEC) = 3
8931 exit_group(0)    ... one per child
8929 wait4(-1, NULL, WNOHANG, NULL) = 8931 ... 8934, then -1 ECHILD
8929 unlink("/dev/shm/ad-ipc-8929") = 0
8929 exit_group(0)
```

- `openat("/dev/shm/ad-ipc-<pid>", O_CREAT|O_EXCL, 0600)` is what
  `shm_open` becomes: POSIX shared memory is a file in the `/dev/shm` tmpfs.
  `O_EXCL` fails if the name exists, 0600 keeps other users out.
- `ftruncate(3, 4240)` sizes it to `struct ring` (16 path slots of 256 bytes,
  the three semaphores, head/tail and the counters) before `mmap`.
- `pipe2` creates the result pipe before the fork, so every child inherits
  both ends.
- `clone(... SIGCHLD)` five times is `fork()`: 1 producer and 4 consumers.
  `SIGCHLD` in the flags is the signal the parent gets when the child dies.
- Each child ends with `exit_group(0)`. The parent then calls
  `wait4(-1, WNOHANG)` until `ECHILD`, which reaps all 5 (`reaped=5`).
- `unlink` removes the shared memory name, so nothing stays in `/dev/shm`.

## 5. Interpretation

- **The mutex makes the result exact.** With it, every path is consumed
  exactly once: 3785 results and 102 899 712 bytes, equal to what the
  producer measured with `st_size`, in every run, in the pilot and in the VM.
- **Without it the race shows up every time.** Two consumers can read the
  same `tail` before either advances it. One slot is then processed twice
  and the next one never. So results can be fewer (lost paths) or more
  (duplicates beat the losses) than the files: 3781 to 3789 here. Run 2 is
  the interesting one: 3785 results, the right count, yet 11 MB of bytes
  missing. Lost and duplicated paths cancelled out in the count but not in
  the bytes, which is why the program checks both.
- **The semaphores alone are not enough.** `full` and `empty` count slots,
  so they stop the producer from overrunning the ring and the consumers from
  reading an empty slot. They do not make the read-modify-write of `tail`
  atomic. That is the job of `mutex`, the binary semaphore around the
  critical section. Turning it off is the only change in `--unsafe` (plus a
  `sched_yield()` that widens the window so the race appears every run).
- **No zombies.** A child that exits stays a zombie until its parent calls
  `wait`. The strace shows the parent calling `wait4(-1, WNOHANG)` once per
  child and stopping at `ECHILD`, and `reaped=5` confirms all 5 were
  collected. After SIGTERM, `zombies=0` too: the parent forwards the signal
  to its children, waits for them, and exits with 130.
- **Clean shutdown.** `shm_left=0` after SIGTERM and the `unlink` at the end
  of the strace show the shared memory object is removed in both paths. If
  it were not, the 4240-byte object would stay in `/dev/shm` until reboot.
