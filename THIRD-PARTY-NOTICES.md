# Third-party notices / 第三方声明

This repository is a fork of **EQMonitor**.

```
EQMonitor
Copyright (c) 2026 Ryotaro Onoue
Licensed under the MIT License — https://github.com/YumNumm/EQMonitor/blob/main/LICENSE
```

## What comes from upstream / 来自上游的部分

- **Entire UI layer**: layouts, screens, widgets, Material 3 / M3E design system, color tokens, typography, spacing,
  icon set used inside the UI, animations, settings surface, about/license widgets, adaptive icon & splash scaffolding.
- App architecture, Riverpod providers, routing, DI wiring, build scripts (`mise`, `melos`, `tool/asset_pack`).
- Japanese localization resources and upstream documentation (`docs/`, `.agents/`, `CONTRIBUTING.md`).

The upstream project remains the owner of all visual design and component code. This fork does not claim any UI
authorship; changes here are limited to functional layers listed in `README.md`.

## What this fork adds / 本 fork 新增

- Global data feeds (USGS earthquake GeoJSON, NOAA / tsunami.gov Atom) and their parsers.
- ntfy transport + in-app direct polling, deduplication and the notification channel set.
- `lib/core/i18n/app_strings.dart` (Chinese/English runtime switching) and the settings language selector.
- Earthquake / tsunami list screens with magnitude- and severity-based color grading and an on-screen legend.
- Launcher icon artwork, notification small icon and the in-app icon image (locally generated PNG/vector assets,
  not part of the upstream design system).
- `tool/quake-push/pusher.py`, the reference push poller.

## Data sources / 数据来源

- USGS Earthquake Hazards Program feeds — public domain (U.S. Government work).
- NOAA / NWS tsunami.gov Atom feeds — public domain.
- Notification transport: [ntfy](https://ntfy.sh) (Apache-2.0 server, public topic).

This app is **not affiliated with EQMonitor, USGS, NOAA or JMA**. It is a personal, unofficial build.
