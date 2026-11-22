# QuakePush · 地震海啸推送

> ### ⚠️ AI-written documentation
> **Every Markdown file in this repository — this README, `README.zh-CN.md`, `docs/screenshots.md` and the GitHub
> release notes — was written by an AI assistant** (Doubao / 豆包 办公模式 Agent), on the maintainer's instruction, not
> by a human writer. The code changes in this fork (data sources, push links, colour grading, map home, i18n, release
> build fix) were produced by the same AI in the same working sessions, then compiled and run to check them.
> So: the factual claims below reflect what was actually built and observed, but the prose has **not** been
> line-by-line reviewed by a person. Verify anything you rely on.
>
> What the AI did **not** do: invent the UI. Layouts, design system, components, animations and the settings skeleton
> are upstream [EQMonitor](https://github.com/YumNumm/EQMonitor) code.

English | [简体中文](./README.zh-CN.md)

An Android client built by forking **[EQMonitor](https://github.com/YumNumm/EQMonitor) v3.0.1**: the Japan-only JMA data
sources are replaced with **USGS** (global earthquakes) and **NOAA / tsunami.gov** (tsunami bulletins), plus a second
push path that needs no server at all.

Upstream is MIT-licensed, © 2026 Ryotaro Onoue. **All UI credit belongs to the upstream authors**; this fork only
changes functional layers on top of that interface.

---

## Download

Release builds are attached to the GitHub release:
**<https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1>**

| File | ABI | Size | Direct link |
| --- | --- | --- | --- |
| `QuakePush-v3.0.1-arm64-v8a.apk` | arm64-v8a — nearly every phone from ~2016 on (incl. Redmi K80 / HyperOS) | 80.5 MB | [download](https://github.com/Zero4499/EQMonitor/releases/download/quakepush-v3.0.1/QuakePush-v3.0.1-arm64-v8a.apk) |
| `QuakePush-v3.0.1-armeabi-v7a.apk` | armeabi-v7a — older 32-bit ARM devices | 77.1 MB | [download](https://github.com/Zero4499/EQMonitor/releases/download/quakepush-v3.0.1/QuakePush-v3.0.1-armeabi-v7a.apk) |
| `QuakePush-v3.0.1-x86_64.apk` | x86_64 — emulators only | 82.6 MB | [download](https://github.com/Zero4499/EQMonitor/releases/download/quakepush-v3.0.1/QuakePush-v3.0.1-x86_64.apk) |

Signed release builds (`isMinifyEnabled = true`, `isShrinkResources = false`). All three share the application id
`sbs.ourstv.quakepush`, so install exactly one:

```bash
adb install -r QuakePush-v3.0.1-arm64-v8a.apk
```

Debug builds (~180–210 MB per ABI, useful only for debug symbols) stay on CDN:
[arm64-v8a](https://aka.doubaocdn.com/s/GTPFIZLDUH) ·
[armeabi-v7a](https://aka.doubaocdn.com/s/6y0k20HsFV) ·
[x86_64](https://aka.doubaocdn.com/s/eIHRbiqGqO).

## What this fork changes

| | Upstream EQMonitor | Here |
| --- | --- | --- |
| Data | JMA earthquake info / EEW through a private backend | USGS `all_day.geojson`, tsunami.gov Atom feeds |
| Push | Upstream backend + FCM | ntfy topic **and** in-app direct polling, mutually deduplicated |
| Channels | Upstream set | `global_earthquake`, `global_tsunami`, `global_alert` |
| App id | `net.yumnumm.eqmonitor` | `sbs.ourstv.quakepush`, own signing key |
| Language | Japanese-first | 简体中文 / English, switchable at runtime and persisted |
| Home | Map-first, draggable panel | Same map-first structure, global epicenter layer instead of Japan |
| Backend | Private `eqmonitor-backend` required | None — public feeds only |
| Debug chrome | DEBUG ribbon in debug builds | Removed |

## How it works

- **Map-first home.** A full-screen MapLibre map using the same engine and the same `MapOptions` / `MapLibreMap` /
  `CircleStyleLayer` APIs as upstream. Loaded USGS events are drawn as circles whose colour and radius follow magnitude.
  Content sits in an upstream-style `DraggableScrollableSheet` (44 % ⇄ 88 %, snapping) sliding over the map: magnitude
  filter chips with a live count, both push-link statuses, the three largest events, list/settings entries, the 20 most
  recent events.
- **Two push paths.** (1) A small VPS runs `tool/quake-push/pusher.py`, polls USGS + tsunami.gov and publishes to an ntfy
  topic; the app subscribes to that NDJSON stream with `dart:io`. (2) The app polls the same public feeds itself (90 s /
  180 s). Both paths deduplicate by event id, so one event alerts once.
- **Alert grade.** M ≥ 7, PAGER red, or tsunami Warning/Threat goes to `global_alert`: max importance, alarm usage,
  `category=alarm`, ongoing, full-screen intent.
- **Colour grading.** Earthquakes: grey-blue → blue → green → gold → orange → orange-red → red, one band per magnitude
  step, with a legend row and a matching left bar / badge / chevron. Tsunami bulletins: Warning/Threat red,
  Watch/Advisory orange, Information blue.
- **UI language.** Settings offers 简体中文 / English; applies instantly, stored in `shared_preferences` under
  `app_ui_locale_v1`, and direct-feed notification text follows the choice.

## What was actually verified

- Release build installed and launched on an Android 16 emulator (1080×2400): map renders, both push links report
  connected, ~210 USGS events load and plot.
- **Notifications work in the release build.** Posting a message to the ntfy topic produced a notification in the shade,
  with the app's own Q icon as the small icon. Root cause of the earlier silent release builds: R8 resource shrinking
  removed `ic_notification_icon`, which is only referenced from Dart strings. `isShrinkResources` is now `false` and
  `res/raw/keep.xml` pins the icons.
- Chinese/English switching applies without a restart and survives one.
- Row colours on both lists match their bands; the map layer drops out when a magnitude filter excludes everything.

Not verified: no physical phone (Redmi K80) run, no lock-screen full-screen-intent capture, and the Kotlin foreground
service does not exist — the ntfy stream only lives while the process does.

## Screenshots

Real runs of the release build, not mockups.

| Map-first home | Notification, release build | Panel expanded | Settings |
| --- | --- | --- | --- |
| ![home](https://aka.doubaocdn.com/s/21gV5dPhVC) | ![notification](https://aka.doubaocdn.com/s/oRd365wdRU) | ![sheet](https://aka.doubaocdn.com/s/J6aSOQBnNm) | ![settings](https://aka.doubaocdn.com/s/JY6X8v9jtE) |

More: [`docs/screenshots.md`](./docs/screenshots.md). The launcher icon is a personal mark (blue gradient square, white
circled «Q»), not an upstream asset:
![icon](https://aka.doubaocdn.com/s/x5COitJjsV)

## Build

Flutter 3.47 / Dart 3.x, JDK 17, Android SDK 36, and a `key.properties` next to `app/android/` pointing at your own
keystore (template in `app/android/key.properties.example`).

```bash
cd app
flutter pub get
flutter build apk --release --split-per-abi \
  --dart-define=FLAVOR=dev \
  --dart-define=REST_API_URL=https://dev.v2.api.eqmonitor.app \
  --dart-define=WS_API_URL=wss://dev.v2.api.eqmonitor.app/ws \
  --dart-define=APP_NAME="地震海啸推送" \
  --dart-define=IS_PRODUCTION=false \
  --dart-define=SKIP_ONBOARDING=true
```

Gotchas worth knowing before you build:

- The upstream backend URLs are unused here, but upstream bootstrap code still reads them — pass placeholders as above.
- `app/environment/environment` is a symlink upstream and its `.env` files are absent, so everything is injected with
  `--dart-define`.
- Missing `assets/platform/` only prints "unable to find directory entry" warnings. Upstream's asset-pack map style is
  unusable without it, so MapLibre points at the public key-free style
  `https://tiles.openfreemap.org/styles/positron`; the map widgets stay upstream's.
- `--split-per-abi` yields 77–83 MB release APKs; debug variants are 180–210 MB.

The launcher / notification icons and the in-app icon are locally generated PNGs and are **not** in git (binary and
personal artwork). Drop your own `ic_launcher`, `ic_launcher_round`, `ic_notification_icon` into
`app/android/app/src/main/res/`. Everything else needed to build is here.

## Credits

- Upstream: **EQMonitor**, MIT, © 2026 Ryotaro Onoue — <https://github.com/YumNumm/EQMonitor>. `LICENSE` is kept as-is;
  new files here are MIT too.
- UI, design system and visual identity: upstream work. Full attribution list in `THIRD-PARTY-NOTICES.md`.
- Documentation and code changes in this fork: written by an AI assistant under the maintainer's direction, as stated at
  the top of this file.
- Not affiliated with EQMonitor, USGS, NOAA or JMA. Personal, unofficial build.
