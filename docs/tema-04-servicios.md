# Theme 4: Service management · Owner: Magdaleno Gómez Díaz

## 1. What was implemented

- **`ad-monitor.service`** (`systemd/ad-monitor.service` +
  `systemd/ad-monitor.sh`). A long-running daemon that writes the kernel's
  pressure stall information (`/proc/pressure/{cpu,memory,io}` avg10) and the
  load average to the journal every 10 s. Load stays flat while PSI shows
  the resource is short, so it is the useful signal.
  - Dependencies: `Wants=` + `After=systemd-journald.socket`, `After=local-fs.target`.
  - Restart policy: `Restart=on-failure`, `RestartSec=2s`, at most 5 starts in 60 s.
  - Limits: `CPUQuota=20%`, `MemoryMax=64M`, `MemorySwapMax=0`, `TasksMax=32`.
  - Sandbox: `DynamicUser=yes`, `ProtectSystem=strict`, `ProtectHome=yes`,
    `PrivateTmp=yes`, `NoNewPrivileges=yes`.
  - For the experiment `/etc/arch-distro/monitor.env` can set
    `LOAD_WORKERS` (busy loops inside the unit) and `LOAD_MEM_MIB`.
- **`ad-report.timer` → `ad-report.service`**. Oneshot health report to
  `/var/log/arch-distro/report-<date>.log`, 5 min after boot and then daily
  (`Persistent=true` catches up after downtime).
- `ad-svc` (`bin/ad-svc`) reads the unit's cgroup files (`cpu.max`,
  `cpu.stat`, `memory.max`, `memory.current`, `memory.events`) and
  `ad-svc crash` kills the main process with SIGKILL.

## 2. Operating systems concept

- systemd as PID 1: units, dependencies, restart policy. Resource control
  with **cgroups v2**: the `cpu` controller enforces `cpu.max` (quota/period,
  for example `20000 100000`) by throttling the group once it used its quota
  in the period. The `memory` controller reclaims and finally OOM-kills
  inside the group when `memory.max` is reached. Silberschatz et al. 10th
  ed., ch. 2 (OS services, system boot), ch. 5 (scheduling), ch. 18 (Virtual
  Machines, containers and resource isolation). man `systemd.resource-control(5)`.

## 3. Measurement method

```sh
experiments/exp-04-svc.sh
```

1. `systemctl show` of the limits, `systemd-cgls -u ad-monitor.service`,
   `systemctl list-timers ad-report.timer`.
2. Quota: `LOAD_WORKERS=2` (2 busy loops = up to 200% of a CPU without
   limit). The unit's `usage_usec` from `cpu.stat` is read 20 s apart.
   CPU% = Δusage / (20 s × 10⁶) × 100. Also `nr_throttled`.
3. Memory: `LOAD_MEM_MIB=128` against `MemoryMax=64M`. Cgroup OOM kills
   counted from the kernel log since the step started
   (`journalctl -k --since @<start>`, lines `Memory cgroup out of memory`),
   because `memory.events` starts again at 0 each time systemd recreates
   the cgroup. Also `NRestarts`.
4. Restart: `ad-svc crash` (SIGKILL to the main PID). `NRestarts` before/after
   and the journal.

## 4. Results

VM, 6 vCPU. Raw data: `results/tema-04/<ts>/1-cgroup.txt` … `4-restart.txt`.
The script ran 4 times; the table uses the last run (19:35 UTC) and the
"other runs" column shows the earlier ones.

| Test | Expected | Measured (last run) | Other runs |
|------|----------|---------------------|------------|
| `systemctl show` | quota 20%, 64 MiB, on-failure / 2 s | `CPUQuotaPerSecUSec=200ms`, `MemoryMax=67108864`, `Restart=on-failure`, `RestartUSec=2s` | same |
| cgroup | own cgroup | `/system.slice/ad-monitor.service` holding `ad-monitor.sh` and its `sleep` | same |
| timer | scheduled | `ad-report.timer` last ran 19:29, next 00:06 | same |
| CPU of the unit with 2 busy workers (20 s) | ≤ 20% | 20.1% of one CPU | 20.0%, 20.0%, 20.1% |
| `nr_throttled` during the quota step | grows | 230 periods | 230, 231, 230 |
| `cpu.max` | `20000 100000` | `20000 100000` | same |
| cgroup OOM kills asking 128 MiB | ≥ 1 | 2 (process `tail`, `CONSTRAINT_MEMCG`) | kernel log shows the same `tail` kill |
| `NRestarts` after the memory step | n/a | 2 | 2, 2, 2 |
| `NRestarts` after SIGKILL | +1, active again in about 2 s | 0 → 1, killed 19:35:45, `Started` 19:35:47 | same in run 3; runs 1–2 hit the start limit (below) |

Kernel log line of a kill:

```text
Memory cgroup out of memory: Killed process 10467 (tail) total-vm:69920kB,
anon-rss:64200kB ... oom_memcg=/system.slice/ad-monitor.service
```

## 5. Interpretation

- **CPUQuota.** Two busy loops want 200% of a CPU. `CPUQuota=20%` becomes
  `cpu.max = 20000 100000`: the group may run 20 ms in every 100 ms period.
  Once the group used its 20 ms the kernel takes all its threads off the
  CPU until the next period. Over 20 s that is 200 periods, and the counter
  grew by about 230 (it also counts the settle time before the window). The
  measured 20.0–20.1% is the quota exactly, with sampling error.
- **MemoryMax.** The helper (`head -c 128M /dev/zero | tail`) needs about
  128 MiB, twice the limit. The memory controller first tries to reclaim
  inside the group. There is nothing to reclaim (anonymous memory, and
  `MemorySwapMax=0` forbids swap), so it OOM-kills inside the group only.
  It chose `tail`, the biggest process (64 MiB RSS), not the small main
  script. Nothing outside the cgroup was touched.
- **Why the unit restarted twice in the memory step.** systemd's default
  `OOMPolicy=stop`: when the kernel OOM-kills any process of a service,
  systemd stops the whole unit with result `oom-kill`. That counts as a
  failure, so `Restart=on-failure` starts it again, the new `tail` hits the
  limit again, and the cycle repeats. That is why `NRestarts` reached 2.
  `memory.events` showed 0 kills after the restarts because each restart
  creates a new cgroup with fresh counters, which is why the kills are
  counted from the kernel log.
- **Restart after SIGKILL.** Death by signal is a failure for
  `Restart=on-failure`, so systemd restarted the unit after `RestartSec=2s`
  (killed 19:35:45, started 19:35:47). `systemctl stop` would not restart it:
  SIGTERM is handled by the script, which exits 0.
- **Start limit.** In the first two runs the crash came right after the OOM
  restarts. With `StartLimitBurst=5` in 60 s, the restart after the crash
  hit the limit (`start-limit-hit`) and the unit stayed failed. This is the
  protection working as designed: a unit that keeps dying is not restarted
  forever. The experiment now runs `systemctl reset-failed` before each step
  so every step starts from a clean counter.
