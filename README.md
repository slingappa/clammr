# Clammr

**Clamshell mode without closing the lid.**

A tiny macOS menu bar app that turns your MacBook's built-in display **fully off** while an external monitor is connected — lid stays open, keyboard and trackpad stay usable.

```
┌──────────────────────────────────────┐
│ 💻  Built-in Display          [●━━]  │
│     On · 1 external display          │
├──────────────────────────────────────┤
│ ✓ Keep Off After Wake/Reconnect      │
│   Launch at Login                    │
├──────────────────────────────────────┤
│   Quit (restores display)        ⌘Q  │
└──────────────────────────────────────┘
```

## Why

macOS only disables the internal panel in clamshell mode (lid closed). With the lid open, dimming to zero brightness still leaves the panel as an active display — windows wander onto it, the cursor gets lost there, and the GPU keeps driving it.

Clammr **detaches** the panel instead: macOS treats it as unplugged, windows move to the external display, the backlight goes off.

## Features

- One switch to turn the built-in display off / on
- Refuses to turn off when no external display is connected
- **Auto-restores** the built-in display if the external monitor is unplugged
- **Keep Off After Wake/Reconnect** — re-detaches the panel when macOS brings it back after sleep
- Quitting restores the display
- Launch at Login
- Single Swift file, no dependencies, ~250 lines

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`)
- Tested on Apple Silicon, macOS 26

## Build & install

```sh
git clone https://github.com/slingappa/clammr.git
cd clammr
./build.sh            # builds ./Clammr.app
./build.sh install    # copies to ~/Applications and launches
```

The app is ad-hoc signed. On first launch macOS may block it — right-click **Clammr.app → Open**.

## Usage

1. Connect an external monitor.
2. Click the laptop icon in the menu bar.
3. Flip the **Built-in Display** switch off.

The icon shows a slash while the built-in display is off.

## If your screen goes black

The change only lasts for the current login session. To recover:

- Unplug the external monitor — Clammr turns the built-in display back on, or
- Quit Clammr (`killall Clammr` in Terminal) — quitting restores the display, or
- Log out / restart.

## How it works

Clammr calls the private CoreGraphics/SkyLight function `CGSConfigureDisplayEnabled` inside a standard display-configuration transaction, scoped to the current session:

```swift
CGBeginDisplayConfiguration(&cfg)
CGSConfigureDisplayEnabled(cfg, builtinID, false)
CGCompleteDisplayConfiguration(cfg, .forSession)
```

A `CGDisplayRegisterReconfigurationCallback` watches for monitors being plugged / unplugged and for sleep / wake, so the app can restore or re-detach the panel. See [design.md](design.md) for full details.

## Caveats

- Uses a **private, undocumented Apple API**. A future macOS update may break it. Not App Store eligible.
- Not affiliated with Apple. Inspired by the "disconnect display" feature of [BetterDisplay](https://github.com/waydabber/BetterDisplay); Clammr does only this one thing.

## License

MIT — see [LICENSE](LICENSE).
