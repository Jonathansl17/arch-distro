# Keyboard shortcuts

Source: arch-config's `sxhkd/sxhkdrc`, used without changes. Reload after an
edit: `pkill -USR1 -x sxhkd` (sxhkd rereads its config on SIGUSR1).
Designer of every shortcut: Jonathan Sancho Loaiza.

## Mandatory shortcuts (statement A.5)

The distro keeps arch-config's own keys for the mandatory actions.

| Required action | Key in this distro | Command |
|-----------------|--------------------|---------|
| Open terminal | `Ctrl + <` | `alacritty-cwd` (opens in the focused window's directory) |
| Close active window | `Ctrl + Q` | `bspc node -c` |
| Application launcher | none | there is no rofi/dmenu. Apps have direct keys (see below) |
| Switch workspace | `Super + 1..9, 0` | `bspc desktop -f N` |

The statement names `Super + Enter`, `Super + W/Q` and `Super + D`. These
keys are bound differently here (see the tables below).

## Windows and terminals

| Keys | Action |
|------|--------|
| `Ctrl + <` | New alacritty in the focused window's directory (`alacritty-cwd` reads it from `/proc/<pid>/cwd`) |
| `Ctrl + Q` | Close focused window (`bspc node -c`) |
| `Ctrl + Shift + A / D / W / S` | Split left / right / up / down with a new terminal |
| `Ctrl + ← → ↑ ↓` | Focus neighbour window |
| `Ctrl + Shift + ← → ↑ ↓` | Swap with neighbour |
| `Ctrl + Alt + ← →` | Send window to previous / next monitor |
| `Alt + Tab` | Toggle between the last two windows |
| `Ctrl + Alt + Tab` | Leave fullscreen and cycle windows on this desktop |
| `Ctrl + .` | Toggle fullscreen |
| `Super + ← → ↑ ↓` | Grow window |
| `Super + Shift + ← → ↑ ↓` | Shrink window |

## Desktops

| Keys | Action |
|------|--------|
| `Super + 1..9, 0` | Go to desktop 1..10 |
| `Super + Shift + 1..9, 0` | Move window to desktop and follow it |
| `Super + Ctrl + 1..9, 0` | Move every window of the current desktop to desktop N and follow (or just go there if empty) |

## Applications and system

| Keys | Action |
|------|--------|
| `Super + B` | Brave |
| `Super + W` | Brave web app |
| `Super + S` | Brave web app (second one) |
| `Super + D` | Discord |
| `Super + E` | File manager (pcmanfm) |
| `Super + P` | Postman |
| `Super + T` | Telegram |
| `Super + O` | OBS |
| `Super + L` | Lock screen (slock, PAM password) |
| `Super + A` | Select all in alacritty and copy |
| `Print` | Area screenshot to `~/screenshots` and clipboard |
| `Super + F1 / F2 / F3` | Mute / volume down / volume up (PipeWire `wpctl`) |
| `Super + F4 / F7 / F8` | Mic mute / down / up |

## Free shortcuts per member (3 each)

All of them come from arch-config and were designed by Jonathan Sancho Loaiza.
Each member presents and explains three.

| Member | Keys | What it does | OS interface |
|--------|------|--------------|--------------|
| Jonathan Sancho Loaiza | `Print` | area screenshot saved to `~/screenshots` and copied to the clipboard | X selections (`clipcopy`) |
| Jonathan Sancho Loaiza | `Super + L` | lock the screen | PAM authentication (`slock`) |
| Jonathan Sancho Loaiza | `Alt + Tab` | toggle between the last two windows | bspwm UNIX socket (`bspc`) |
| Magdaleno Gómez Díaz | `Ctrl + Shift + A / D / W / S` | split and open a terminal in the same directory | `/proc/<pid>/cwd` (`alacritty-cwd`) |
| Magdaleno Gómez Díaz | `Super + Ctrl + 1..9, 0` | move every window of the desktop to desktop N | bspwm UNIX socket |
| Magdaleno Gómez Díaz | `Ctrl + .` | toggle fullscreen | bspwm UNIX socket |
| Jennifer López Miranda | `Super + F1 / F2 / F3` | output mute / volume down / up | PipeWire (`wpctl`) |
| Jennifer López Miranda | `Super + F4 / F7 / F8` | microphone mute / down / up | PipeWire (`wpctl`) |
| Jennifer López Miranda | `Ctrl + Alt + ← →` | send window to the other monitor | RandR outputs via bspwm |

The statement also asks for at least one shortcut per member that runs an
`ad-*` command or a Capa 2 function. These keys do not do that yet.
