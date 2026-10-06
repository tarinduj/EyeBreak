# EyeBreak

A tiny macOS menu bar app for the 20-20-20 rule: every 20 minutes of screen time, a full-screen overlay reminds you to look at something 20 feet (6 m) away for 20 seconds.

- **Lightweight:** one Swift file, ~11 MB memory, 0% CPU when idle. Fully event-driven, no polling.
- **Smart clock:** the 20 minutes restart when you unlock the screen, wake the Mac or display, or finish a break. Paused while locked or asleep.
- **Menu bar 👁 icon:** next-break countdown, enable/disable (remembered), take a break now, quit.
- **Overlay:** covers every display (including full-screen apps), counts down 20 s, chimes when done. Click or press Esc to skip.
- **Starts at login** via a launchd agent.

## Install

Requires the Xcode Command Line Tools (`xcode-select --install` if `swiftc` is missing).

```sh
git clone https://github.com/tarinduj/EyeBreak.git ~/EyeBreak
~/EyeBreak/install.sh        # or: install.sh 30  for a 30-minute interval
```

## Usage

- Restart after quitting: `launchctl kickstart gui/$(id -u)/local.eyebreak` (it also comes back at next login)
- Uninstall: `~/EyeBreak/uninstall.sh`
