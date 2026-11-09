# Window manager choice: bspwm

## Choice

bspwm (tiling window manager) driven by sxhkd (hotkey daemon), started from
TTY1 with `startx`, with no display manager and no desktop environment. Status
bar: lemonbar fed by a custom C daemon. All of this comes from arch-config.

Reasons:

1. **Few moving parts.** bspwm only manages windows and takes commands over a
   UNIX socket (`bspc`), and sxhkd only maps keys to commands. That makes each
   process easy to tie to an OS concept: X clients, a UNIX socket, signals
   (`pkill -USR1 sxhkd` reloads the keybindings).
2. **Low idle footprint.** No compositor, no settings daemons, no indexers.
3. **Scriptable.** Every action is a shell command, so the custom commands of
   Capa 3 plug in without plugins.

Main drawback: no GUI settings. Wi-Fi, audio and displays are handled with
`nmcli`, `wpctl` and `xrandr` or with arch-config's wrappers.

## Measurement

Comparison against **XFCE 4**, a lightweight but complete desktop
environment, on the same VM and the same user.

Method:

```sh
sudo pacman -S --needed xfce4        # only for the comparison
# Session A: normal login on TTY1 (bspwm). Open one terminal, wait 2 min:
experiments/exp-00-dewm.sh bspwm
# Session B: log out, on TTY2 log in and run:
startx /usr/bin/startxfce4 -- :1
# open one terminal, wait 2 min:
experiments/exp-00-dewm.sh xfce
```

The script takes 5 samples, 10 s apart, of `free -m` used memory, the number
of processes owned by the user (`ps -u`) and their proportional set size (PSS)
from `smem`. PSS splits each shared page among the processes that map it. RSS
would count shared libraries once per process and inflate the total.

## Results

Pending: paste the average of the 5 samples per session from
`results/dewm/summary.csv`.

| Session | Used RAM (MiB) | User processes | User PSS (MiB) |
|---------|----------------|----------------|----------------|
| bspwm | | | |
| XFCE 4 | | | |

## Interpretation

Pending, to be filled once the data is in. Expected: XFCE starts xfwm4,
xfce4-panel, xfdesktop, xfsettingsd, xfce4-power-manager and a notification
daemon, so it should have more processes and more PSS than bspwm + sxhkd +
lemonbar. Check whether the difference in `free` (system-wide) matches the
difference in PSS (session only). Kernel caches and buffers explain any gap.
