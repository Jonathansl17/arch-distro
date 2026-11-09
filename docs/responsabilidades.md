# Responsibility matrix

Every member is the main owner of at least 2 themes and 2 free commands. The
owner must be able to explain, modify live and defend their components
without help.

| Theme | Main owner | Support | Repository path | Evidence sheet |
|-------|------------|---------|-----------------|----------------|
| 1 · Processes and scheduling | Jonathan Sancho Loaiza | Jennifer López Miranda | `src/ad-ps/`, `experiments/exp-01-sched.sh` | [tema-01](tema-01-procesos.md) |
| 2 · Memory | Jonathan Sancho Loaiza | Magdaleno Gómez Díaz | `src/ad-mem/`, `memory/`, `lib/step-memory.sh`, `experiments/exp-02-mem.sh` | [tema-02](tema-02-memoria.md) |
| 3 · File system | Magdaleno Gómez Díaz | Jonathan Sancho Loaiza | `bin/ad-snap`, `lib/step-btrfs.sh`, `experiments/exp-03-*.sh` | [tema-03](tema-03-sistema-archivos.md) |
| 4 · Service management | Magdaleno Gómez Díaz | Jennifer López Miranda | `systemd/`, `bin/ad-svc`, `experiments/exp-04-svc.sh` | [tema-04](tema-04-servicios.md) |
| 5 · Concurrency and IPC | Jennifer López Miranda | Jonathan Sancho Loaiza | `src/ad-ipc/`, `experiments/exp-05-ipc.sh` | [tema-05](tema-05-ipc.md) |
| 6 · Package management | Magdaleno Gómez Díaz | Jonathan Sancho Loaiza | `pacman/`, `bin/ad-pkg`, `lib/step-tools.sh`, `experiments/exp-06-pkg.sh` | [tema-06](tema-06-paquetes.md) |
| 7 · Boot process | Jonathan Sancho Loaiza | Magdaleno Gómez Díaz | `bin/ad-boot`, `experiments/exp-07-boot.sh` | [tema-07](tema-07-arranque.md) |
| 8 · I/O and devices | Jennifer López Miranda | Magdaleno Gómez Díaz | `udev/`, `modprobe/`, `bin/ad-dev`, `experiments/exp-08-dev.sh` | [tema-08](tema-08-dispositivos.md) |
| 9 · Protection and security | Jennifer López Miranda | Jonathan Sancho Loaiza | `security/`, `lib/step-security.sh`, `bin/ad-sec`, `experiments/exp-09-*.sh` | [tema-09](tema-09-seguridad.md) |

The statement asks for 7 of the 9 themes. All 9 are implemented. Before the
final delivery the team states here which 7 are submitted for grading, picking
the ones with complete measured evidence.

**Themes submitted for grading:** pending.

## Capa 1 and Capa 3

| Component | Owner | Path |
|-----------|-------|------|
| Manual install + installation log | each member, own VM | `docs/instalacion.md`, `logs/<name>/` |
| Bootstrap `install.sh` | Jonathan Sancho Loaiza | `install.sh`, `lib/` |
| DE/WM justification | Jonathan Sancho Loaiza | `docs/de-wm.md` |
| Mandatory command `ad-info` | team (Jonathan main) | `src/ad-info/` |
| Free commands | Jonathan: `ad-ps`, `ad-mem` · Magdaleno: `ad-svc`, `ad-pkg` · Jennifer: `ad-ipc`, `ad-dev` | `src/`, `bin/` |
| Extra commands | Magdaleno: `ad-snap` · Jonathan: `ad-boot` · Jennifer: `ad-sec` | `bin/` |
| Shortcuts + cheatsheet | Jonathan Sancho Loaiza | `docs/cheatsheet.md` |
