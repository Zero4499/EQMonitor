# Screenshots / 界面截图

> **AI-written file.** This page was written by an AI assistant (豆包 办公模式 Agent).
> 本页由 AI 撰写，内容未经人工校对。

Captured from real runs of this fork's **release build** on an Android 16 emulator (1080×2400) with live USGS /
tsunami.gov data, 2026-11-22. No mockups, no AI-rendered UI — every pixel is the app actually running.

全部截图均为本 fork **release 包**在安卓模拟器上的实际运行画面（1080 × 2400，USGS / tsunami.gov 实时数据，
2026-11-22），没有任何效果图或 AI 生成图。

The layouts, typography and colour system come from upstream
[YumNumm/EQMonitor](https://github.com/YumNumm/EQMonitor) (MIT, © 2026 Ryotaro Onoue). What this fork added:
the epicenter layer on that map, magnitude/tsunami colour grading with a legend, the language switch, the Q icon.

界面结构、字体与配色体系来自上游项目 [YumNumm/EQMonitor](https://github.com/YumNumm/EQMonitor)
（MIT，© 2026 Ryotaro Onoue）。本 fork 只加了地图上的震中图层、震级/海啸分级配色与图例、语言切换、Q 图标。

## 1. Map-first home / 地图即首页

Map fills the screen, the sheet sits at its 44 % resting height. Filter chips with a live count, both push links
green, the three largest events.

地图铺满，面板停在 44% 的停留高度；带计数的筛选 chips、双链路全绿、最强三条。

![Map home](https://aka.doubaocdn.com/s/21gV5dPhVC)

## 2. Notification in a release build / release 包弹通知

A message posted to the ntfy topic arriving in the shade, with the app's own Q as the small icon — the check that
proved the R8 resource-shrinking fix.

往 ntfy 主题发一条消息，通知栏收到，小图标是本应用的 Q —— 这就是验证「关掉资源压缩」修好了的那个证据。

![Release notification](https://aka.doubaocdn.com/s/oRd365wdRU)

## 3. Panel expanded / 面板拉到最高

The sheet at 88 %, revealing the recent-events list; every row carries its magnitude colour dot.

面板到 88%，露出「最近事件」列表，每行带震级色点。

![Panel expanded](https://aka.doubaocdn.com/s/J6aSOQBnNm)

## 4. Earthquake list / 地震列表

Left 4 px colour bar, magnitude badge tint and chevron share one colour derived from the magnitude; the legend row
on top explains the bands.

左侧 4px 色条、震级圈底色与箭头同色，颜色都由震级推出；顶部一行图例解释分档。

![Earthquake list](https://aka.doubaocdn.com/s/t1O0QBAJAG)

## 5. Tsunami bulletins / 海啸公报

`warning` / `threat` → red, `watch` / `advisory` → orange, otherwise blue (Information).

`warning` / `threat` 为红，`watch` / `advisory` 为橙，其余（Information）为蓝。

![Tsunami bulletins](https://aka.doubaocdn.com/s/IUWfRhOuhR)

## 6. Language switch / 界面语言切换

Settings offers 简体中文 / English; it applies immediately and persists (`app_ui_locale_v1` in
`shared_preferences`).

设置页可选简体中文 / English，即时生效并持久保存（`shared_preferences` 里的 `app_ui_locale_v1`）。

![Settings](https://aka.doubaocdn.com/s/JY6X8v9jtE)

## 7. Launcher icon / 桌面图标

The Q mark (blue gradient square, white circled Q) appears in the drawer, in Settings, and as the notification small
icon.

Q 标识（蓝渐变底 + 白色圆圈 Q）出现在抽屉、设置页顶部，以及通知小图标上。

![Icon](https://aka.doubaocdn.com/s/x5COitJjsV)

![Drawer](https://aka.doubaocdn.com/s/G60bR02soL)
