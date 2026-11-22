# QuakePush

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B.svg)](https://flutter.dev)
[![Release](https://img.shields.io/badge/Release-v3.0.1-orange.svg)](https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1)
[![Discord](https://img.shields.io/badge/Discord-join%20chat-5865F2?logo=discord&logoColor=white)](https://discord.gg/wW6tXzSdpv)

> **Fair warning up front:** this README, the release notes and the code changes below were written by an AI assistant (the Doubao / 豆包 work-mode agent) at my request. I haven't proofread every line. Where the prose and the code disagree, trust the code.

The interface isn't mine either — layout, design system, components and animations all come from upstream [EQMonitor](https://github.com/YumNumm/EQMonitor). I only swapped the functional layers underneath.

[English](./README.md) · [简体中文](./README.zh-CN.md) · [日本語](./README.ja.md)

---

## What this is

A fork of EQMonitor v3.0.1. The JMA-only data path was pulled out and replaced with **USGS** for global earthquakes and **tsunami.gov** for tsunami bulletins, plus a second push route that does not depend on my server at all. Application id is `sbs.ourstv.quakepush`, and the only app name it carries is `QuakePush`.

Upstream is MIT-licensed, © 2026 Ryotaro Onoue. All credit for the UI goes to them.

## Which file to install

Release page: <https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1>

| File | Who it's for | Size |
| --- | --- | --- |
| `QuakePush-v3.0.1-arm64-v8a.apk` | basically any phone from ~2016 onwards (Redmi K80 / HyperOS included) | 80.6 MB |
| `QuakePush-v3.0.1-armeabi-v7a.apk` | older 32-bit ARM devices | 77.2 MB |
| `QuakePush-v3.0.1-x86_64.apk` | emulators only | 82.8 MB |

All three share one application id, so install exactly one:

```bash
adb install -r QuakePush-v3.0.1-arm64-v8a.apk
```

These are signed release builds (`isMinifyEnabled = true`, `isShrinkResources = false`).

## Features

- **Global earthquake feed**: USGS `all_day.geojson`, deduplicated by event id so one quake rings once.
- **Tsunami bulletins**: tsunami.gov (PTWC / NTWC) Atom feeds, colour-coded by Warning / Watch / Information.
- **Two push routes, both alive**:
  1. A small box of mine runs `tool/quake-push/pusher.py`, polls both feeds and publishes to an ntfy topic the app subscribes to.
  2. The app also polls USGS and tsunami.gov itself (90 s / 180 s), so it still works if the server is down.
- **Map like the USGS event page**: USGS Topo raster basemap served by The National Map (no API key), with the USGS GHSC plate boundaries bundled offline as a GeoJSON overlay. Epicentres are coloured and sized by magnitude; tapping one opens that event's details.
- **Push conditions are yours to set**: minimum magnitude (M2.5 / M4.5 / M6.0), tsunami level (all bulletins / advisory and up / warnings only), or alert grade only. Whatever you pick, M7+, PAGER red and tsunami Warning/Threat always get through — that's the whole point of installing this.
- **Three UI languages**: 简体中文 / English / 日本語, switched in settings, applied instantly and remembered across restarts.
- **Do Not Disturb exception**: the app asks for notification policy access and recreates its channels after grant, so earthquake and tsunami alerts can still interrupt DND.
- **Only my notification channels remain**: `global_earthquake`, `global_tsunami`, `global_alert`, `service_fallback`. The upstream channels (`eew_*`, `tsunami_*`, `VXSE*`…) are deleted on startup, so people upgrading don't end up with a screen full of EQ leftovers.
- **First launch asks for everything at once**: notifications, full-screen intent, exact alarms, DND access, battery optimisation exemption. The settings page has a button to run it again. Skipping the battery exemption means the ROM kills the process and you never see a push — that one is not optional.

## Screenshots

Real release-build captures on an Android 16 emulator (1080×2400), not mockups.

| Home — 简体中文 | Home — English | Home — 日本語 |
| --- | --- | --- |
| ![Home in Chinese](https://aka.doubaocdn.com/s/h5tWil2Jgf) | ![Home in English](https://aka.doubaocdn.com/s/twV3Fkc0VF) | ![Home in Japanese](https://aka.doubaocdn.com/s/z3kidghnsa) |

| Settings | Event detail | Push test panel |
| --- | --- | --- |
| ![Settings](https://aka.doubaocdn.com/s/bQ7CnjVqhU) | ![Event detail](https://aka.doubaocdn.com/s/D9LjOqSo55) | ![Push test panel](https://aka.doubaocdn.com/s/WIqnLppTbO) |

More captures live in [`docs/screenshots.md`](./docs/screenshots.md).

## What I actually ran, and what bit me

Repeated release installs on an Android 16 emulator (1080×2400): the USGS Topo basemap renders, plate boundary lines show up along the trenches, both links report connected, ~200 USGS events plot, tapping a dot opens the sheet, the permission prompts come up one after another on first run, filters survive a restart, and an ntfy message really does show up in the shade with the Q as the small icon.

Things that bit me, so they don't bite you:

- **Release builds with no notifications**: R8 decided `ic_notification_icon` was unused (only referenced from a Dart string) and stripped it. Fixed with `isShrinkResources = false` and a `res/raw/keep.xml` keep rule.
- **Background death**: Android will happily kill the process; battery exemption plus autostart permission is the only thing that keeps it alive.
- **DND access**: the app has to declare `ACCESS_NOTIFICATION_POLICY` in the manifest before it shows up in the system "Modes access / allowed apps" list at all. Existing channels can't have their `bypassDnd` flag changed after creation, so they are deleted and recreated once the policy access is granted.
- **Basemap history**: upstream's map style needs the `assets/platform` asset pack, which a standalone fork doesn't have — calling it throws `AssetPackNotReadyException`. CARTO raster styles want an API key (otherwise a screen full of "API KEY REQUIRED"), OSM's own raster tiles render every country's labels at once, and the OpenFreeMap vector style ships mixed-language place names. Ended up on the USGS Topo raster, same as the USGS event page.
- **`const new._()` is not legal Dart** for a private named constructor — write `const X._()`. I hit this more than once in this fork.

**Not verified**: no run on a real phone (nothing plugged in), no lock-screen full-screen-intent screenshot, and there is no Kotlin foreground service — the ntfy long connection only lives as long as the process does.

## Building it yourself

Flutter 3.47 / Dart 3.x, JDK 17, Android SDK 36, and a `key.properties` next to `app/android/` pointing at your own keystore (template at `app/android/key.properties.example`).

```bash
cd app
flutter pub get
flutter build apk --release --split-per-abi \
  --dart-define=FLAVOR=dev \
  --dart-define=REST_API_URL=https://dev.v2.api.eqmonitor.app \
  --dart-define=WS_API_URL=wss://dev.v2.api.eqmonitor.app/ws \
  --dart-define=APP_NAME=QuakePush \
  --dart-define=IS_PRODUCTION=false \
  --dart-define=SKIP_ONBOARDING=true
```

- The upstream backend URLs are unused here, but upstream bootstrap code still reads them, so pass placeholders.
- `app/environment/environment` is a symlink upstream and its `.env` files aren't there, hence all config arrives via `--dart-define`.
- A missing `assets/platform/` only prints "unable to find directory entry" warnings; it doesn't break the build.
- Release APKs land at 77–83 MB; debug at 180–210 MB.

## Community

- Discord: <https://discord.gg/wW6tXzSdpv>

## Thanks

- Upstream **EQMonitor**, MIT, © 2026 Ryotaro Onoue — <https://github.com/YumNumm/EQMonitor>. `LICENSE` stays as-is; new files here are MIT too.
- Basemap: U.S. Geological Survey, The National Map (USGSTopo). Plate boundaries: USGS GHSC `Plate_Boundaries`.
- UI, design system and visual identity belong to upstream; the full attribution list is in `THIRD-PARTY-NOTICES.md`.
- Not affiliated with EQMonitor, USGS, NOAA or JMA. Personal build — don't rely on it as an official warning system.
