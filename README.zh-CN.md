# QuakePush

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B.svg)](https://flutter.dev)
[![Release](https://img.shields.io/badge/Release-v3.0.1%20(build%204014)-orange.svg)](https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1)
[![Discord](https://img.shields.io/badge/Discord-join%20chat-5865F2?logo=discord&logoColor=white)](https://discord.gg/wW6tXzSdpv)

> **先说清楚：** 这份 README、Release 说明、以及下面的代码改动，都是 AI（豆包办公模式的 Agent）按我的要求写的，我没逐字校对。跟代码对不上的地方，以代码为准。

界面也不是我画的 —— 布局、设计系统、组件、动效全是上游 [EQMonitor](https://github.com/YumNumm/EQMonitor) 的，我只是在它上面换功能层。

[English](./README.md) · 简体中文 · [日本語](./README.ja.md)

---

## 这是个什么

我把 EQMonitor v3.0.1 fork 过来，把原来只服务日本气象厅的那套数据源换掉：地震用 **USGS** 的全球数据，海啸用 **tsunami.gov** 的公报，再加一条完全不依赖服务器的推送。包名 `sbs.ourstv.quakepush`，应用名只有 `QuakePush` 一个。

上游是 MIT，© 2026 Ryotaro Onoue。UI 的功劳全归上游作者。

## 装哪个

Release 页：<https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1>

| 文件 | 适合谁 | 体积 |
| --- | --- | --- |
| `QuakePush-3.0.1-2014-arm64-v8a.apk` | 2016 年之后的手机基本都是（红米 K80 / 澎湃 OS 也行） | 85.5 MB |
| `QuakePush-3.0.1-2014-armeabi-v7a.apk` | 老一点的 32 位 ARM 设备 | 82.0 MB |
| `QuakePush-3.0.1-2014-x86_64.apk` | 只在模拟器上用 | 87.8 MB |

三个包共用同一个包名，装一个就行：

```bash
adb install -r QuakePush-3.0.1-2014-arm64-v8a.apk
```

都是签名 release 包（`isMinifyEnabled = true`，`isShrinkResources = false`）。

## 功能

- **全球地震流**：USGS `all_day.geojson`，按事件 id 去重，同一件事只响一次。
- **海啸公报**：tsunami.gov（PTWC / NTWC）Atom 源。地图上公报画成空心分级色环 + 三道白浪；同一次事件被两条公报各报一次时，合并成一个标记。
- **两条推送链路并存**：
  1. 我自己那台小机器跑 `tool/quake-push/pusher.py`，轮询两个源后发到 ntfy 主题，App 订阅。
  2. App 自己直连 USGS 和 tsunami.gov 轮询（地震 90 秒、海啸 180 秒），服务器挂了也能收。
- **主页实时刷新**：列表和地图按这个轮询节奏自动刷新，主页标题行右侧显示最近一次成功同步的「更新于 HH:mm:ss」时间戳。
- **跟 USGS 事件页同款地图**：底图是 The National Map 提供的 USGS Topo 栅格（免密钥），USGS GHSC 板块边界作为离线内置 GeoJSON 叠加。震中按震级上色、放大；点一下圆点弹出这条事件详情。有在途公报时，相机自动飞到公报点一次。
- **App 内更新检查**：查询本仓库最新 GitHub Release 并比对 versionCode；有新版时弹窗并在浏览器打开下载页，不在 App 内下载或安装 APK。
- **推送条件可以自己定**：最小震级（M2.5 / M4.5 / M6.0）、海啸级别（全部公报 / 关注级以上 / 只要警报）、只推警报级。无论怎么设，M7+、PAGER red、海啸 Warning/Threat 这三种永远放行 —— 这才是装它的意义。
- **三语界面**：简体中文 / English / 日本語，设置里切换，立即生效、重启保持。
- **只留自己的通知渠道**：共六个 —— M7 以下地震、M7.0–7.9、M8.0+、海啸公报、警报级、兜底，各自独立的呼吸灯颜色和振动节奏。渠道本身不出声，提示音由 App 原生 MediaPlayer 走通知音量播放。上游和历史遗留渠道在启动时逐个删掉，升级上来的人不会再看到一屏 EQ 旧渠道。
- **设置页通知区只有两条**：一条一键申请全部权限（通知、全屏 intent、勿扰访问、电池白名单），一条测试通知（端到端 / 本地 / 警报级），从推送测试面板发起。
- **勿扰模式例外**：申请通知策略访问权限，授权后重建渠道，地震和海啸警报在勿扰模式下也能打断。

## 截图

都是红米 K80（Android 17，澎湃 OS）release 包实跑截图，不是效果图。见 [`docs/screenshots.md`](./docs/screenshots.md)。

## 实测与踩过的坑

红米 K80（Android 17，澎湃 OS）上验证过：USGS Topo 底图出图，海沟沿线板块边界可见，两条链路都显示已连接，USGS 事件上图，点圆点弹详情，首启权限弹窗依次出现，筛选设置重启后保留，ntfy 消息真能弹到通知栏，海啸环和白浪盖在公报震中位置，主页时间戳每轮刷新都在跳动。

踩过的几个坑，省得你也踩：

- **release 包不弹通知**：R8 把 `ic_notification_icon` 当无用资源裁了（它只被 Dart 字符串引用）。现在 `isShrinkResources = false`，外加 `res/raw/keep.xml` 钉住图标。
- **后台被杀**：安卓默认会掐后台，电池白名单 + 允许自启动才稳。
- **渠道声音**：国产 ROM（尤其 HyperOS）经常不认渠道里设的自定义铃声，渠道设置页还会显示「声音：无」。所以渠道按设计保持静音，提示音改由 App 侧播放。
- **勿扰访问**：Manifest 里必须先声明 `ACCESS_NOTIFICATION_POLICY`，应用才会出现在系统「免打扰访问 / 允许应用」列表里。已有渠道的 `bypassDnd` 标记创建后不能改，所以授权后要删掉重建。
- **底图遍历史**：上游地图样式依赖 `assets/platform` 资源包，独立 fork 里没有，直接用会 `AssetPackNotReadyException`。CARTO 栅格要 API key，OSM 官方栅格各国文字全糊一张图，OpenFreeMap 矢量样式地名多语言混排。最后用了 USGS Topo 栅格，跟 USGS 事件页一致。
- **`const new._()` 这种私有命名构造是非法的**，得写 `const X._()`，这行我在这份 fork 里改了好几次。

**还没验证**：锁屏全屏 intent 没有单独截图取证；也没有 Kotlin 前台服务 —— ntfy 长连接只在进程活着时有效。

## 想自己编

Flutter 3.47 / Dart 3.x、JDK 17、Android SDK 36，`app/android/` 下放一个 `key.properties` 指向你自己的 keystore（模板在 `app/android/key.properties.example`）。

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

- 上游后端地址在这儿用不上，但上游启动代码还会读，随便传个占位值就行。
- `app/environment/environment` 是个符号链接，`.env` 拿不到，所有配置靠 `--dart-define` 注入。
- 缺 `assets/platform/` 只会刷「unable to find directory entry」警告，不影响编译。
- release 包 82–88 MB，debug 约 385 MB。

## 社区

- Discord：<https://discord.gg/wW6tXzSdpv>

## 谢谢你读到这里

- 上游 **EQMonitor**（MIT，© 2026 Ryotaro Onoue）：<https://github.com/YumNumm/EQMonitor>。`LICENSE` 原样保留，这里新增的文件也走 MIT。
- 底图：U.S. Geological Survey, The National Map（USGSTopo）。板块边界：USGS GHSC `Plate_Boundaries`。
- UI、设计系统、视觉识别都是上游的成果，完整署名在 `THIRD-PARTY-NOTICES.md`。
- 跟 EQMonitor、USGS、NOAA、JMA 都没关系，纯个人非官方构建，别拿去当官方预警用。
