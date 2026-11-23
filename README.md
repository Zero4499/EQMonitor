# QuakePush

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B.svg)](https://flutter.dev)
[![Release](https://img.shields.io/badge/Release-v3.0.1%20(build%204014)-orange.svg)](https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1)
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
| `QuakePush-3.0.1-2014-arm64-v8a.apk` | basically any phone from ~2016 onwards (Redmi K80 / HyperOS included) | 85.5 MB |
| `QuakePush-3.0.1-2014-armeabi-v7a.apk` | older 32-bit ARM devices | 82.0 MB |
| `QuakePush-3.0.1-2014-x86_64.apk` | emulators only | 87.8 MB |

All three share one application id, so install exactly one:

```bash
adb install -r QuakePush-3.0.1-2014-arm64-v8a.apk
```

These are signed release builds (`isMinifyEnabled = true`, `isShrinkResources = false`).

## Features

- **Global earthquake feed**: USGS `all_day.geojson`, deduplicated by event id so one quake rings once.
- **Tsunami bulletins**: tsunami.gov (PTWC / NTWC) Atom feeds. On the map a bulletin shows as a hollow, grade-coloured ring with a three-stroke wave glyph; the same event reported by two bulletins is collapsed into one marker.
- **Two push routes, both alive**:
  1. A small box of mine runs `tool/quake-push/pusher.py`, polls both feeds and publishes to an ntfy topic the app subscribes to.
  2. The app also polls USGS and tsunami.gov itself (quakes 90 s, tsunami 180 s), so it still works if the server is down.
- **Live home feed**: the list and map refresh on that polling cadence, and the home header shows an "Updated HH:mm:ss" timestamp for the last successful sync.
- **Map like the USGS event page**: USGS Topo raster basemap served by The National Map (no API key), with the USGS GHSC plate boundaries bundled offline as a GeoJSON overlay. Epicentres are coloured and sized by magnitude; tapping one opens that event's details. When an active bulletin arrives, the camera flies to it once.
- **In-app update check**: the app queries this repo's latest GitHub Release and compares versionCode. If a newer build exists it shows a dialog and opens the download page in the browser — it does not download or install an APK inside the app.
- **Push conditions are yours to set**: minimum magnitude (M2.5 / M4.5 / M6.0), tsunami level (all bulletins / advisory and up / warnings only), or alert grade only. Whatever you pick, M7+, PAGER red and tsunami Warning/Threat always get through — that's the whole point of installing this.
- **Three UI languages**: 简体中文 / English / 日本語, switched in settings, applied instantly and remembered across restarts.
- **Own notification channels only**: six channels — earthquake below M7, M7.0–7.9, M8.0+, tsunami bulletin, alert grade, fallback — each with its own LED colour and vibration pattern. The channels themselves stay silent; the alert tone is played in-app by a native MediaPlayer over the notification stream. Upstream and legacy channels are deleted on startup, so people upgrading don't end up with a screen full of EQ leftovers.
- **Settings notification area is two entries only**: one to grant all permissions at once (notifications, full-screen intent, DND access, battery whitelist), and one to run a test notification (end-to-end / local / alert-level) from the push test panel.
- **Do Not Disturb exception**: the app asks for notification policy access and recreates its channels after grant, so earthquake and tsunami alerts can still interrupt DND.

## Screenshots

Real release-build captures on a Redmi K80 (Android 17, HyperOS), not mockups. See [`docs/screenshots.md`](./docs/screenshots.md).

## What I actually ran, and what bit me

Verified on a Redmi K80 (Android 17, HyperOS): the USGS Topo basemap renders, plate boundary lines show up along the trenches, both links report connected, USGS events plot on the map, tapping a dot opens the sheet, the permission prompts come up one after another on first run, filters survive a restart, an ntfy message really does show up in the shade, the tsunami ring and wave glyph render over the bulletin epicentre, and the home timestamp advances on each refresh.

Things that bit me, so they don't bite you:

- **Release builds with no notifications**: R8 decided `ic_notification_icon` was unused (only referenced from a Dart string) and stripped it. Fixed with `isShrinkResources = false` and a `res/raw/keep.xml` keep rule.
- **Background death**: Android will happily kill the process; battery exemption plus autostart permission is the only thing that keeps it alive.
- **Channel sound**: domestic ROMs (HyperOS in particular) often ignore a custom ringtone set on a notification channel, and the channel settings page shows "Sound: none". The channels are therefore silent by design; the tone is played from the app side instead.
- **DND access**: the app has to declare `ACCESS_NOTIFICATION_POLICY` in the manifest before it shows up in the system "Modes access / allowed apps" list at all. Existing channels can't have their `bypassDnd` flag changed after creation, so they are deleted and recreated once the policy access is granted.
- **Basemap history**: upstream's map style needs the `assets/platform` asset pack, which a standalone fork doesn't have — calling it throws `AssetPackNotReadyException`. CARTO raster styles want an API key, OSM's own raster tiles render every country's labels at once, and the OpenFreeMap vector style ships mixed-language place names. Ended up on the USGS Topo raster, same as the USGS event page.
- **`const new._()` is not legal Dart** for a private named constructor — write `const X._()`. I hit this more than once in this fork.

**Not yet verified**: lock-screen full-screen intent has no dedicated screenshot evidence, and there is no Kotlin foreground service — the ntfy long connection only lives as long as the process does.

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
- Release APKs land at 82–88 MB; debug around 385 MB.

## Community

- Discord: <https://discord.gg/wW6tXzSdpv>

## Thanks

- Upstream **EQMonitor**, MIT, © 2026 Ryotaro Onoue — <https://github.com/YumNumm/EQMonitor>. `LICENSE` stays as-is; new files here are MIT too.
- Basemap: U.S. Geological Survey, The National Map (USGSTopo). Plate boundaries: USGS GHSC `Plate_Boundaries`.
- UI, design system and visual identity belong to upstream; the full attribution list is in `THIRD-PARTY-NOTICES.md`.
- Not affiliated with EQMonitor, USGS, NOAA or JMA. Personal build — don't rely on it as an official warning system.
