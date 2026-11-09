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
3. Memory: `LOAD_MEM_MIB=128` against `MemoryMax=64M`. Check `oom_kill` in
   `memory.events` and `journalctl -k -g oom`.
4. Restart: `ad-svc crash` (SIGKILL to the main PID). `NRestarts` before/after
   and the journal.

## 4. Results

Pending (VM).

| Test | Expected | Measured |
|------|----------|----------|
| CPU of the unit with 2 busy workers | ≤ 20% | |
| `nr_throttled` grows | yes | |
| `oom_kill` after asking 128 MiB | ≥ 1, main process alive | |
| `NRestarts` after SIGKILL | +1, active again within ~2 s | |

## 5. Interpretation

Pending. Explain why 2 busy loops (200% demand) are capped at 20%. Also
explain why the OOM kill hits the `tail` helper and not the main script:
the OOM killer picks the largest process in the cgroup. And explain why
SIGKILL counts as a failure for `Restart=on-failure` (exit by signal), while
`systemctl stop` (SIGTERM, handled, exit 0) does not restart it.
