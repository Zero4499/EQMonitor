# QuakePush

Fair warning up front: **this README, the release notes and the code changes below were written by an AI assistant (the Doubao / 豆包 work-mode agent) at my request. I haven't proofread every line.**
Where the prose and the code disagree, trust the code.

The interface isn't mine either — layout, design system, components and animations all come from upstream [EQMonitor](https://github.com/YumNumm/EQMonitor). I only swapped the functional layers underneath.

English | [简体中文](./README.zh-CN.md)

---

## What this is

A fork of EQMonitor v3.0.1. I pulled out the JMA-only data path and put in **USGS** for global earthquakes and **tsunami.gov** for tsunami bulletins, then added a second push route that doesn't need a server at all. Application id is `sbs.ourstv.quakepush`, and the only name it carries is `QuakePush`.

Upstream is MIT-licensed, © 2026 Ryotaro Onoue. All credit for the UI goes to them.

## Which file to install

Release page: <https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1>

| File | Who it's for | Size |
| --- | --- | --- |
| `QuakePush-v3.0.1-arm64-v8a.apk` | basically any phone from ~2016 onwards (Redmi K80 / HyperOS included) | 80.5 MB |
| `QuakePush-v3.0.1-armeabi-v7a.apk` | older 32-bit ARM devices | 77.1 MB |
| `QuakePush-v3.0.1-x86_64.apk` | emulators only | 82.7 MB |

All three share one application id, so install exactly one:

```bash
adb install -r QuakePush-v3.0.1-arm64-v8a.apk
```

These are signed release builds (`isMinifyEnabled = true`, `isShrinkResources = false`). Debug builds exist only for logs and live on a CDN:
[arm64-v8a](https://aka.doubaocdn.com/s/GTPFIZLDUH) ·
[armeabi-v7a](https://aka.doubaocdn.com/s/6y0k20HsFV) ·
[x86_64](https://aka.doubaocdn.com/s/eIHRbiqGqO).

## What I tore out, what I added

- **Data**: JMA earthquake info / EEW → USGS `all_day.geojson` plus tsunami.gov Atom feeds. The private backend is no longer needed.
- **Two push routes, both alive**: a small box of mine runs `tool/quake-push/pusher.py`, polls both feeds and publishes to an ntfy topic that the app subscribes to; and the app also polls USGS and tsunami.gov itself (90 s / 180 s). Everything is deduplicated by event id, so one quake rings once.
- **Only my notification channels remain**: `global_earthquake`, `global_tsunami`, `global_alert`, `service_fallback`. The 22 upstream channels (`eew_*`, `tsunami_*`, `VXSE*`…) get deleted on startup, so people upgrading don't end up with a screen full of EQ leftovers.
- **First launch asks for everything at once**: notifications, full-screen intent, exact alarms, do-not-disturb access, battery optimisation exemption. The settings page has a button to run it again. (Skipping the battery exemption means the ROM kills the process and you never see a push — that one is not optional.)
- **Push conditions are yours to set**: minimum magnitude (M2.5 / M4.5 / M6.0), tsunami level (all bulletins / advisory and up / warnings only), or alert grade only. Whatever you pick, M7+, PAGER red and tsunami Warning/Threat always get through — that's the whole point of installing this.
- **The home screen is the map**: full-screen MapLibre with a light vector basemap (Positron, served by OpenFreeMap, no key needed, OSM/OpenFreeMap attribution in the footer). Epicentres are coloured and sized by magnitude, and **tapping one opens that event's details** — same sheet you get from the list.
- **No splash image anymore**: the old Q gradient is gone; cold start is one screen of light grey that turns straight into the map.
- **Language**: 简体中文 / English, switched in settings, applied instantly and remembered across restarts.
- **Odds and ends**: the upstream DEBUG ribbon is gone; launcher and notification icons are my own Q mark (generated locally, not in git).

## What I actually ran, and what bit me

Repeated release installs on an Android 16 emulator (1080×2400): map renders, both links report connected, ~200 USGS events plot, tapping a dot opens the sheet, the permission prompts come up one after another on first run, filters survive a restart, and an ntfy message really does show up in the shade with the Q as the small icon.

Things that bit me, so they don't bite you:

- **Release builds with no notifications**: R8 decided `ic_notification_icon` was unused (only referenced from a Dart string) and stripped it. Fixed with `isShrinkResources = false` and a `res/raw/keep.xml` keep rule.
- **Background death**: Android will happily kill the process; battery exemption plus autostart permission is the only thing that keeps it alive.
- **Basemap**: upstream's map style needs the `assets/platform` asset pack, which a standalone fork doesn't have — calling it throws `AssetPackNotReadyException`. Raster styles like CARTO want an API key (otherwise a screen full of "API KEY REQUIRED"), and OSM's own raster tiles render every country's labels at once, which looks terrible. Ended up on vector Positron.
- **`const new._()` is not legal Dart** for a private named constructor — write `const X._()`. I hit this more than once in this fork.

**Not verified**: no run on a real phone (nothing plugged in), no lock-screen full-screen-intent screenshot, and there is no Kotlin foreground service — the ntfy long connection only lives as long as the process does.

## Screenshots

Real release-build captures, not mockups.

| Map home | Tapping a dot | Panel expanded | Settings |
| --- | --- | --- | --- |
| ![home](https://aka.doubaocdn.com/s/qib1sLwVZD) | ![detail](https://aka.doubaocdn.com/s/TAES3qdXYf) | ![sheet](https://aka.doubaocdn.com/s/J6aSOQBnNm) | ![settings](https://aka.doubaocdn.com/s/JY6X8v9jtE) |

The icon (blue gradient, white circled Q):
![icon](https://aka.doubaocdn.com/s/x5COitJjsV)

More in [`docs/screenshots.md`](./docs/screenshots.md).

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

## Thanks

- Upstream **EQMonitor**, MIT, © 2026 Ryotaro Onoue — <https://github.com/YumNumm/EQMonitor>. `LICENSE` stays as-is; new files here are MIT too.
- UI, design system and visual identity belong to upstream; the full attribution list is in `THIRD-PARTY-NOTICES.md`.
- Not affiliated with EQMonitor, USGS, NOAA or JMA. Personal build — don't rely on it as an official warning system.
