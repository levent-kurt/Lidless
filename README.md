# Lidless

A native macOS menu bar utility for Apple Silicon Macs. Trigger **Blackout
Mode** with a global shortcut and the screen (and keyboard backlight) goes
completely dark — while the Mac itself stays fully awake underneath, so
background jobs, renders, downloads, or builds keep running overnight
without a glowing display or keyboard lighting up the room.

Lidless drives every connected display's hardware brightness to zero,
holds power assertions so the system never idles or sleeps, and turns the
keyboard backlight off. A touch of keyboard or mouse activity past a
configurable threshold ends Blackout Mode instantly.

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon (M1/M2/M3) — the project builds `arm64` only
- Xcode or the Xcode Command Line Tools, to build
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the
  `.xcodeproj` (installed automatically by `scripts/build.sh` via Homebrew
  if missing)

## Features

- **Menu bar only** — `LSUIElement`, no Dock icon, no app switcher entry.
- **Global shortcut** (default `⌘F6`, re-recordable in Preferences) toggles
  Blackout Mode from anywhere.
- **Hardware-level blackout** — every active display's brightness driven to
  0 via `DisplayServicesSetBrightness`, and restored to its previous level
  on exit.
- **Keyboard backlight off** during Blackout, restored to its previous
  level on exit.
- **Power assertions** (`IOPMAssertionCreateWithName`) prevent idle system
  sleep and idle display sleep, so background work keeps running.
- **Configurable wake sensitivity** — minimum keystrokes (1–5, default 3)
  and/or continuous mouse movement (duration and/or pixel distance) needed
  to exit Blackout Mode, via a listen-only `CGEventTap`.
- **Accessibility permission onboarding** — checked with `AXIsProcessTrusted()`
  on every launch; if missing, a modal explains why it's needed and links
  straight to System Settings → Privacy & Security → Accessibility.
- **Launch at Login**, via `SMAppService` (macOS 13+ native API, no helper
  app required).

## Project layout

```
Lidless/
├── project.yml                        XcodeGen spec (generates Lidless.xcodeproj)
├── Resources/
│   ├── Info.plist
│   ├── Lidless.entitlements           App Sandbox disabled — see note below
│   └── Assets.xcassets/AppIcon.appiconset/   App icon (all sizes)
├── Sources/Lidless/
│   ├── App/                           @main SwiftUI App + AppDelegate
│   ├── StatusBar/                     NSStatusItem + menu
│   ├── Blackout/                      BlackoutController, DisplayBrightnessController
│   ├── Power/                         PowerAssertionManager (IOKit)
│   ├── Keyboard/                      Keyboard backlight control (see below)
│   ├── Input/                         EventTapMonitor (CGEventTap wake watchdog)
│   ├── Permissions/                   Accessibility check + onboarding UI
│   ├── Hotkey/                        Carbon-based global shortcut + recorder UI
│   ├── Preferences/                   Settings store, SwiftUI view, window
│   └── LaunchAtLogin/                 SMAppService wrapper
└── scripts/
    ├── build.sh                       xcodegen generate + xcodebuild (Release, arm64)
    └── build_dmg.sh                   Builds the app, then packages a drag-to-install .dmg
```

## Building

```sh
scripts/build.sh
```

This runs `xcodegen generate` to produce `Lidless.xcodeproj` from
`project.yml`, then builds a Release, `arm64`-only `Lidless.app` into
`build/Build/Products/Release/`.

## Packaging a DMG

```sh
scripts/build_dmg.sh
```

Builds the app, then produces `dist/Lidless-<version>.dmg` with the classic
drag-to-install layout: `Lidless.app` on the left, a shortcut to
`/Applications` on the right. Uses `create-dmg` if it's installed (or
installable via Homebrew); otherwise falls back to a plain
`hdiutil` + AppleScript recipe that needs nothing beyond stock macOS tools.

For real distribution outside this repo, sign with a Developer ID
certificate and notarize the app before packaging — see the note on
sandboxing below for why Developer ID (rather than the Mac App Store) is
the right distribution path for this app.

## Why the app isn't sandboxed

Core capabilities Lidless depends on are unavailable under the macOS App
Sandbox:

- A listen-only `CGEventTap` for detecting wake-up activity
- `IOPMAssertionCreateWithName` power assertions
- The private `DisplayServices` and `CoreBrightness` frameworks used for
  display and keyboard brightness control

`Resources/Lidless.entitlements` disables the App Sandbox accordingly. This
is standard for this class of system utility (Amphetamine, Lunar,
MonitorControl, etc.) and means distribution is via Developer ID + notarization,
not the Mac App Store.

## Display and keyboard backlight control

There is no public macOS API for either of these, so both go through
private frameworks, resolved by name at runtime (so a future OS change that
reshapes either one degrades to a no-op rather than crashing):

- **Display brightness** (`Sources/Lidless/Blackout/DisplayBrightnessController.swift`)
  uses the private `DisplayServices` framework's
  `DisplayServicesGetBrightness` / `DisplayServicesSetBrightness` on each
  active `CGDirectDisplayID`.
- **Keyboard backlight** (`Sources/Lidless/Keyboard/KeyboardBacklightController.swift`)
  uses CoreBrightness's private `KeyboardBrightnessClient` class — its
  `copyKeyboardBacklightIDs`, `brightnessForKeyboard:`, and
  `setBrightness:fadeSpeed:commit:forKeyboard:` selectors, invoked via
  `objc_msgSend` since no header ships for this class.

## Preferences

- **Global Shortcut** — click the recorder field and press a new
  combination (must include at least one modifier key).
- **Wake-Up Sensitivity** — minimum keystrokes (1–5) and/or continuous
  mouse movement (duration in seconds, and/or total pixel distance)
  required to end Blackout Mode. Either the keystroke threshold or a mouse
  threshold ends it — whichever is reached first.
- **Launch at Login** — registers Lidless as a login item via
  `SMAppService`.
