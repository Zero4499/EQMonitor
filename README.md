# QuakePush · 地震海啸推送 (Earthquake & Tsunami Push)

English | [简体中文](./README.zh-CN.md)

A personal Android build that turns the open-source **[EQMonitor](https://github.com/YumNumm/EQMonitor)** app into a
global earthquake / tsunami notification client, using **USGS** and **NOAA/NWS tsunami.gov** feeds instead of the
Japan-only JMA feeds, plus a second, server-independent direct-feed path.

> **Attribution first:** this project is a **fork / derivative of EQMonitor v3.0.1** by
> [@YumNumm](https://github.com/YumNumm), licensed under the MIT License.
> **The entire UI — layouts, widgets, design-system, colors, icons-from-the-design-system, animations, settings screens,
> Material 3 / M3E component styling, and the app icon grid/splash scaffolding — comes from the upstream project.**
> This fork only adds/removes functional layers (data sources, notification channels, i18n strings, list screens, launcher
> icon artwork) on top of that UI. All UI credit belongs to the upstream authors and contributors.

---

## What is different from upstream EQMonitor

| Area | Upstream EQMonitor | This fork (QuakePush) |
| --- | --- | --- |
| Data source | JMA (Japan) earthquake info / EEW via private backend | **USGS** `all_day.geojson` (global) + **tsunami.gov** Atom feeds (NOAA) |
| Push transport | Upstream private backend + FCM | **ntfy** topic (link 1) + **in-app direct polling** (link 2) |
| Notification channels | Upstream channels | `global_earthquake`, `global_tsunami`, `global_alert` (full-screen + alarm usage) |
| Application ID | `net.yumnumm.eqmonitor` | **`sbs.ourstv.quakepush`** (own signing key, not the official one) |
| UI language | Japanese (+ upstream locales) | **Runtime switch: 简体中文 / English** (persisted) |
| Screens | Japan-oriented map / EEW / intensity views | Global push status home, **earthquake list (color-graded by magnitude)**, **tsunami bulletin list**, simplified settings |
| Debug chrome | Debug banner / version ribbon shown in debug builds | Removed, so debug builds look like release |
| Backend | Requires private `eqmonitor-backend` | **No backend required** — everything works with public feeds |

Everything not listed above — the design system, the overall look & feel, the settings page structure, the notice/about
widgets, the adaptive-icon pipeline — is upstream EQMonitor code and is kept as-is wherever possible.

---

## Features

- **Two independent push paths**
  1. **Cloud host → ntfy**: `tool/quake-push/pusher.py` polls USGS + tsunami.gov and publishes to an ntfy topic; the app
     subscribes with a plain `dart:io` HTTP NDJSON stream (exponential backoff 2 s → 60 s).
  2. **Direct polling in-app**: the app itself polls USGS `all_day.geojson` (90 s) and tsunami.gov `PHEBAtom.xml` /
     `PAAQAtom.xml` (180 s), deduplicates by event id, and posts notifications locally.
     Both paths are deduplicated against each other, so the same event never alerts twice.
- **Alert-grade notifications**: magnitude ≥ 7, PAGER `red`, or tsunami `Warning` / `Threat` go to the `global_alert`
  channel (importance max, `USAGE_ALARM`, `category=alarm`, ongoing, `fullScreenIntent`).
- **Event lists**: earthquake tab with magnitude color grading (grey-blue → blue → green → yellow → orange → red, with an
  on-screen legend), PAGER and tsunami flags, detail dialog; tsunami tab color-coded by bulletin severity
  (Warning/Threat red, Watch/Advisory orange, Information blue).
- **UI language switch** (Chinese / English) inside Settings, applied instantly and persisted in `shared_preferences`.
  Notification text of the direct feed follows the same setting.
- **HyperOS / MIUI friendly**: explicit channel descriptions, `showBadge`, ticker text, and a settings shortcut to the
  system notification channel screen.

## Screenshots

Captured on a Pixel 6 emulator (Android 16, 1080×2400). The PNGs are kept **out of git** so the repository stays light;
run the app and grab your own with `adb exec-out screencap -p > shot.png`, or look for them in the fork's release notes.

What to look for: the push-status home with two green links, the earthquake list with the magnitude legend row and
colored left bars, the tsunami tab, the Settings page with the 简体中文 / English selector, and the English UI.
**Every layout in those captures is the upstream EQMonitor UI** — this fork only added the color grading, the legend row
and the language selector.

## Notification channels

| Channel id | Purpose | Importance / behaviour |
| --- | --- | --- |
| `global_earthquake` | Global earthquakes (USGS), M below alert threshold | Default, sound enabled |
| `global_tsunami` | Tsunami bulletins (tsunami.gov) | Default, sound enabled |
| `global_alert` | Alert grade: M ≥ 7 / PAGER red / tsunami Warning–Threat | Max importance, alarm usage, ongoing, full-screen intent |

## Build

Requirements: Flutter (this fork was built with Flutter 3.47 / Dart 3.x), JDK 17, Android SDK 36, and a `key.properties`
next to `app/android/` pointing at your own keystore.

```bash
# in app/
flutter pub get
flutter build apk --debug \
  --dart-define=FLAVOR=dev \
  --dart-define=REST_API_URL=https://dev.v2.api.eqmonitor.app \
  --dart-define=WS_API_URL=wss://dev.v2.api.eqmonitor.app/ws \
  --dart-define=APP_NAME=QuakePush \
  --dart-define=IS_PRODUCTION=false \
  --dart-define=SKIP_ONBOARDING=true
```

Signing config (`app/android/key.properties`, see `app/android/key.properties.example`):

```properties
storeFile=/absolute/path/to/your.jks
storePassword=***
keyAlias=***
keyPassword=***
```

Notes taken from actually building this fork:

- The upstream private backend (`/ws`, REST) is **not used** by this fork's own features, but the upstream bootstrap code
  still expects those URLs — pass placeholder `--dart-define` values as above.
- `app/environment/environment` is a git symlink upstream; the `.env` files are not available, so everything goes through
  `--dart-define`.
- Missing `assets/platform/` + the bundled asset pack only produce "unable to find directory entry" warnings; the build
  still succeeds. The upstream map/AssetPack feature is not part of this fork.
- **Release builds (R8) do not show local notifications on this device** (channels are created and the service reports
  connected, but `show()` never displays). Debug builds work, therefore the shipped APK is a debug build with the debug
  banner removed.
- **Known limitation**: the ntfy stream lives only while the app process is alive; after the system kills the app, use the
  ntfy client as a fallback for the same topic. A Kotlin foreground service is not implemented yet.

### Binary assets not in git

The launcher / notification icons and the in-app icon are **locally generated PNGs**. They are not committed here
(binary assets, and they are my own artwork rather than upstream design-system assets); drop in your own `ic_launcher`,
`ic_launcher_round` and `ic_notification_icon` under `app/android/app/src/main/res/`. Everything else needed to build is
in the repository.

### Push server

`tool/quake-push/pusher.py` is the reference poller used by this fork (any small VPS with Python 3.12, standard library
only). It publishes markdown messages to an ntfy topic; server, topic and thresholds are environment variables.

## License & credits

- Upstream: **EQMonitor**, MIT License, Copyright (c) 2026 Ryotaro Onoue — <https://github.com/YumNumm/EQMonitor>
- This fork keeps the upstream `LICENSE` untouched. Any file added here is released under the same MIT terms.
- The design system, UI components and visual identity are upstream work; see `THIRD-PARTY-NOTICES.md` at the repository
  root for the full attribution list.
- Not affiliated with EQMonitor, USGS, NOAA or JMA. Personal, unofficial build.
