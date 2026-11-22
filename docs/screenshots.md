# Screenshots / 界面截图

All screenshots are taken from a real build of this fork on an Android emulator
(1080×2400, USGS / tsunami.gov live data, 2026-11-22). No mockups, no AI-rendered UI.

所有截图均为本 fork 的实际构建在安卓模拟器上真机运行所得（1080×2400，USGS / tsunami.gov
实时数据，2026-11-22），没有使用任何效果图或 AI 生成图。

The UI structure, typography, color system and assets are inherited from the upstream
project [YumNumm/EQMonitor](https://github.com/YumNumm/EQMonitor) (MIT, © 2026 Ryotaro Onoue).

界面结构、字体、配色体系与素材均来自上游项目 [YumNumm/EQMonitor](https://github.com/YumNumm/EQMonitor)（MIT，© 2026 Ryotaro Onoue）。

## Home / 首页

Two push links (server → ntfy, and the app polling the feeds directly).
双链路状态：服务器 → ntfy，以及 App 直连轮询。

![Home](https://aka.doubaocdn.com/s/mdpgyyiviT)

## Earthquake list with magnitude colours / 地震列表分级配色

Left colour bar, magnitude badge tint and chevron share the same colour; the legend on top
explains the bands.
左侧色条、震级圈底色与箭头同色，顶部为分档图例。

![Earthquake list](https://aka.doubaocdn.com/s/t1O0QBAJAG)

## Tsunami bulletins / 海啸公报

`warning / threat` → red, `watch / advisory` → orange, otherwise blue (Information).
`warning / threat` 为红，`watch / advisory` 为橙，其余（Information）为蓝。

![Tsunami bulletins](https://aka.doubaocdn.com/s/IUWfRhOuhR)

## UI language switch / 界面语言切换

Settings → 简体中文 / English, applied immediately and persisted (`app_ui_locale_v1`).
设置页可切简体中文 / English，即时生效并持久保存（`app_ui_locale_v1`）。

![Language switch](https://aka.doubaocdn.com/s/gPpVU5lPcL)

![English UI](https://aka.doubaocdn.com/s/goYXjmOMO6)

## Launcher icon / 桌面图标

Epicentre-and-ripples direction: deep navy disc, orange source point, three concentric rings.
震源涟漪方向：深海军蓝圆底、橙色震源点、三层同心涟漪。

![Launcher icon](https://aka.doubaocdn.com/s/LUE72pj5gp)

## Alert-level notification / 警报级通知

Full-screen intent + alarm usage + ongoing, delivered through the `global_alert` channel.
全屏 intent + 闹钟用途 + 持续通知，走 `global_alert` 渠道。

![Alert notification](https://aka.doubaocdn.com/s/z1aq4exJ7c)
