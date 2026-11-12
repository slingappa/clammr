# Clammr — design

Name: "Clammr" = clamshell mode without physically closing the lid.

## Goal
Free menu bar replacement for BetterDisplay's "disconnect built-in display" feature.
Turn the MacBook's internal panel fully off (detached from WindowServer, backlight off,
windows migrate to external) while lid stays open and an external HDMI/USB-C monitor is connected.

## Mechanism
Private SkyLight/CoreGraphics symbol, linked via `@_silgen_name`:

```swift
CGSConfigureDisplayEnabled(CGDisplayConfigRef, CGDirectDisplayID, Bool) -> CGError
```

Called inside a public display-config transaction:
`CGBeginDisplayConfiguration` → `CGSConfigureDisplayEnabled` → `CGCompleteDisplayConfiguration(.forSession)`.
`.forSession` = change reverts on logout/reboot (safety net).

## Finding the built-in display
Disabled displays vanish from `CGGetOnlineDisplayList`, but `CGDisplayIsBuiltin(id)` still returns 1
for the offline built-in ID (verified on Apple Silicon / macOS 26: ID 1). So:
1. online list + `CGDisplayIsBuiltin`, else
2. scan IDs 1…64 for `CGDisplayIsBuiltin(id) == 1`.

## App
Single-file AppKit app (`App.swift`), bundle `Clammr.app`, `LSUIElement=true` (no Dock icon).

Menu bar icon (SF Symbols): `laptopcomputer` (panel on) / `laptopcomputer.slash` (panel off).
Left-click opens menu, rebuilt on every open (`NSMenuDelegate.menuNeedsUpdate`):
- Header "Clammr <version>" (bold, disabled; version from `CFBundleShortVersionString`)
- (bottom, above Quit) "About Clammr" → standard About panel (`orderFrontStandardAboutPanel`, app activated first
  since `LSUIElement`), icon `laptopcomputer.slash`, credits = tagline + clickable `repoURL`, copyright from
  `NSHumanReadableCopyright` in Info.plist. "View on GitHub" → `NSWorkspace.open(repoURL)`.
  `repoURL` = https://github.com/slingappa/clammr (global constant in App.swift).
- Switch row (`SwitchRowView`, custom `NSMenuItem.view`, BetterDisplay-style): laptop icon,
  title "Built-in Display", subtitle "On/Off · N external displays", `NSSwitch` on the right.
  Switch disabled when panel on and no external display (subtitle: "Connect an external display first").
  Switch action `switchChanged(_:)`; menu stays open; `refreshIcon()` also re-syncs the switch on display changes.
- "Keep Off After Wake/Reconnect" checkbox (UserDefaults `keepOff`, default true)
- "Launch at Login" checkbox (`SMAppService.mainApp`)
- "Quit (restores display)" (⌘Q)

### State
`wantOff: Bool` — true only when this app turned the panel off.

### Display change handling
`CGDisplayRegisterReconfigurationCallback` → skip `beginConfigurationFlag` → debounce 0.5 s on main → `reconcile()`:
- built-in offline AND no externals → re-enable built-in, `wantOff=false` (HDMI unplugged safety).
- `wantOff` AND `keepOff` AND built-in online AND externals present → disable again
  (macOS re-enables panel after sleep/wake or lid events).
- refresh icon.

### Exit safety
`applicationWillTerminate` and SIGINT/SIGTERM/SIGHUP: if `wantOff` → re-enable built-in.
Panel turned off by another tool (e.g. BetterDisplay) is not touched on quit.

## Safety rules
1. Never disable when no external display is online.
2. Auto-restore when last external disappears.
3. Recovery if stuck black: quit app (Activity Monitor / `killall Clammr` blind in Terminal), log out, or reboot.

## Files
- `README.md` — user-facing overview, build, usage, recovery.
- `LICENSE` — MIT.
- `.gitignore` — ignores build output `Clammr.app/`.
- `App.swift` — whole app.
- `build.sh` — compiles with `swiftc -O -swift-version 5`, assembles `Clammr.app`
  (Info.plist written inline), ad-hoc codesigns. `./build.sh install` copies to `~/Applications` and launches.

## Limits
- Private API: may break on future macOS; not App Store-safe.
- Unsigned (ad-hoc): first launch may need right-click → Open.
- Built on Apple Silicon, macOS 26, Swift 6.3.
