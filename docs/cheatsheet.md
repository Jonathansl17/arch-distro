# Keyboard shortcuts

Source: arch-config's `sxhkd/sxhkdrc`, used without changes. Reload after an
edit: `pkill -USR1 -x sxhkd` (sxhkd rereads its config on SIGUSR1).
Designer of every shortcut: Jonathan Sancho Loaiza.

## Mandatory shortcuts (statement A.5)

| Required | Status in this distro |
|----------|-----------------------|
| Super + Enter → terminal | **Not bound.** The terminal opens with `Ctrl + <` |
| Super + W / Super + Q → close window | **Not bound.** `Super + W` opens a Brave web app. Windows close with `Ctrl + Q` |
| Super + D → launcher | **Not bound.** `Super + D` opens Discord. There is no rofi/dmenu |
| Super + 1..9 → workspace | Bound (`Super + 1..0`) |

The team decided to keep arch-config's shortcuts as they are. The rubric
treats the first three as mandatory, so this table states the gap openly.

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

## Free shortcuts per member (statement: exactly 3 each)

Not defined. The team kept arch-config's keybindings untouched, so no
shortcut calls the `ad-*` commands yet.
