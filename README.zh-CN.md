# QuakePush · 地震海啸推送

[English](./README.md) | 简体中文

基于开源项目 **[EQMonitor](https://github.com/YumNumm/EQMonitor)** 改造的个人自用安卓客户端：
把日本 JMA 数据源换成 **USGS**（全球地震）与 **NOAA / tsunami.gov**（海啸公报），并加了一条不依赖服务器的直连轮询链路。

> **先说来源：本项目是 EQMonitor v3.0.1 的 fork / 二次开发，原作者 [@YumNumm](https://github.com/YumNumm)，
> 采用 MIT 许可证。**
> **界面（UI）完全来自原项目**：所有布局、组件、设计系统、配色、Material 3 / M3E 组件样式、设置页结构、
> 动效、自适应图标与启动图框架，都是上游 EQMonitor 的成果。本仓库只在其之上增删功能层
> （数据源、通知渠道、多语言文案、列表页、启动器图标绘制），**UI 的功劳全部属于上游作者与贡献者**。

---

## 下载安装包（release 构建，按 ABI 分包）

安装包已作为 GitHub Release 资产上传：
**<https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1>**

| 安装包 | ABI | 体积 | 直链 |
| --- | --- | --- | --- |
| **arm64-v8a** —— 几乎全部 2016 年以后的手机（含红米 K80 / 澎湃 OS） | `arm64-v8a` | 80.5 MB | [下载](https://github.com/Zero4499/EQMonitor/releases/download/quakepush-v3.0.1/QuakePush-v3.0.1-arm64-v8a.apk) |
| **armeabi-v7a** —— 较早的 32 位 ARM 设备 | `armeabi-v7a` | 77.1 MB | [下载](https://github.com/Zero4499/EQMonitor/releases/download/quakepush-v3.0.1/QuakePush-v3.0.1-armeabi-v7a.apk) |
| x86_64 —— 仅模拟器 | `x86_64` | 82.6 MB | [下载](https://github.com/Zero4499/EQMonitor/releases/download/quakepush-v3.0.1/QuakePush-v3.0.1-x86_64.apk) |

都是**已签名的 release 包**（`isMinifyEnabled = true`、`isShrinkResources = false`），通知在 release 也能弹，详见下方构建说明。
三个包共用包名 `sbs.ourstv.quakepush`，只装一个：

```bash
adb install -r QuakePush-v3.0.1-arm64-v8a.apk
```

debug 包（带 Flutter debug 开销，每个 ABI 约 180–210 MB）还放在 CDN 上，要调试符号可用：
[arm64-v8a](https://aka.doubaocdn.com/s/GTPFIZLDUH) ·
[armeabi-v7a](https://aka.doubaocdn.com/s/6y0k20HsFV) ·
[x86_64](https://aka.doubaocdn.com/s/eIHRbiqGqO)。

---

## 与上游的差异

| 项目 | 上游 EQMonitor | 本 fork（地震海啸推送） |
| --- | --- | --- |
| 数据源 | 日本气象厅地震情報 / 紧急地震速报（私有后端） | **USGS** `all_day.geojson`（全球）+ **tsunami.gov** Atom（NOAA） |
| 推送方式 | 上游私有后端 + FCM | **ntfy 主题**（链路 1）+ **App 内直连轮询**（链路 2） |
| 通知渠道 | 上游渠道 | `global_earthquake`、`global_tsunami`、`global_alert`（全屏 + 闹钟级） |
| 包名 | `net.yumnumm.eqmonitor` | **`sbs.ourstv.quakepush`**（自建签名，与官方签名不同） |
| 界面语言 | 日文为主 | **运行时可切换：简体中文 / English**（持久保存） |
| 首页 | 地图铺满 + 可拖动面板（map-first） | **保持同样的 map-first 结构**，只是图层换成全球 USGS 震中 |
| 页面 | 日本向地图 / 紧急地震速报 / 震度 | 全球地图首页 + **地震列表（按震级分级配色）** + **海啸公报列表** + 精简设置 |
| Debug 标识 | debug 包显示 DEBUG 丝带与版本角标 | 已移除，debug 包外观与正式版一致 |
| 后端依赖 | 需要私有 `eqmonitor-backend` | **不需要任何后端**，只用公开数据源 |

表格以外的内容（设计系统、整体观感、设置页骨架、关于/声明组件、图标生成管线）均为上游代码，尽量保持原样。

---

## 功能

- **地图即首页，和上游一样**：MapLibre 地图铺满整屏（引擎与 `MapOptions` / `MapLibreMap` / `CircleStyleLayer` 用法
  都与 EQMonitor 一致），已加载的 USGS 事件按震级配色、控大小画成震中圆圈。内容放在上游同款的
  `DraggableScrollableSheet`（44% ⇄ 88%，带吸附）里浮在地图上方：筛选 chips（全部 / M2.5+ / M4.5+ / M6+ 带实时计数）、
  双链路状态、最强三条、列表与设置入口、最近 20 条。
- **双链路推送**
  1. **云主机 → ntfy**：`tool/quake-push/pusher.py` 轮询 USGS + tsunami.gov 并发布到 ntfy 主题，
     App 用 `dart:io` 的 HTTP NDJSON 流订阅（断线指数退避 2 s → 60 s）。
  2. **App 直连官方源**：App 自己轮询 USGS `all_day.geojson`（90 s）与 tsunami.gov `PHEBAtom.xml` / `PAAQAtom.xml`
     （180 s），按事件 id 去重后本地弹通知。云主机或 ntfy 挂了也能收。两条链路互相去重，同一事件不会重复提醒。
- **警报级通知**：震级 ≥ 7、PAGER 为 red、或海啸 `Warning` / `Threat` 走 `global_alert` 渠道
  （importance 最高、`USAGE_ALARM`、`category=alarm`、常驻、带 `fullScreenIntent`）。
- **事件列表**：地震 Tab 按震级分档配色（灰蓝 → 蓝 → 绿 → 金黄 → 橙 → 橙红 → 红），顶部带颜色图例，
  显示 PAGER 与海啸评估、点击弹详情；海啸 Tab 按公报级别配色（Warning/Threat 红、Watch/Advisory 橙、Information 蓝）。
- **界面语言切换**（中文 / 英文），在设置页即时生效，写入 `shared_preferences`；直连链路的通知文案也跟着切换。
- **轻量动效**，与上游观感一致：面板 420 ms `easeOutCubic` 淡入 + 上移，chip 与状态圆点变色有过渡，
  事件计数交叉淡入，面板在两个停留高度间吸附。
- **澎湃 OS / MIUI 适配**：渠道补非空描述、`showBadge`、ticker 文案，并提供直达系统通知渠道设置页的入口。

## 截图

来自**本 release 包**的真实运行画面（Android 16 模拟器，1080 × 2400）。PNG 不进 git，下面图片是 CDN 副本。

| 地图首页（中文） | release 包真弹通知 | 面板拉到最高 | 设置页（语言切换） |
| --- | --- | --- | --- |
| ![首页](https://aka.doubaocdn.com/s/21gV5dPhVC) | ![通知](https://aka.doubaocdn.com/s/oRd365wdRU) | ![面板](https://aka.doubaocdn.com/s/J6aSOQBnNm) | ![设置](https://aka.doubaocdn.com/s/JY6X8v9jtE) |

启动器图标是自制标识（蓝色渐变方块 + 白色圆圈 Q），不是上游设计系统素材：
![图标](https://aka.doubaocdn.com/s/x5COitJjsV)

**截图里的布局全部是上游 EQMonitor 的 UI**，本 fork 只加了分级配色、图例、上游地图上的震中图层、语言选择器与图标。

## 通知渠道

| 渠道 id | 用途 | 级别 / 行为 |
| --- | --- | --- |
| `global_earthquake` | 全球地震（USGS），未达警报级 | 默认级别，有声音 |
| `global_tsunami` | 海啸公报（tsunami.gov） | 默认级别，有声音 |
| `global_alert` | 警报级：M ≥ 7 / PAGER red / 海啸 Warning–Threat | 最高级别、闹钟用途、常驻、全屏意图 |

## 构建

需要 Flutter（本 fork 用 Flutter 3.47 / Dart 3）、JDK 17、Android SDK 36，以及在 `app/android/` 旁准备
`key.properties` 指向**你自己的**签名密钥。

```bash
# 在 app/，按 ABI 出 release 包（上方 Release 资产就是这样构建的）
flutter pub get
flutter build apk --release --split-per-abi \
  --dart-define=FLAVOR=dev \
  --dart-define=REST_API_URL=https://dev.v2.api.eqmonitor.app \
  --dart-define=WS_API_URL=wss://dev.v2.api.eqmonitor.app/ws \
  --dart-define=APP_NAME="地震海啸推送" \
  --dart-define=IS_PRODUCTION=false \
  --dart-define=SKIP_ONBOARDING=true
```

签名配置（`app/android/key.properties`，模板见 `app/android/key.properties.example`）：

```properties
storeFile=/absolute/path/to/your.jks
storePassword=***
keyAlias=***
keyPassword=***
```

实际踩坑记录：

- 上游私有后端的 `/ws`、REST 地址本 fork 的功能**不使用**，但上游启动流程仍会读，所以照上面传占位值。
- 上游 `app/environment/environment` 是 git 符号链接，`.env` 文件取不到，全部改用 `--dart-define` 注入。
- 缺 `assets/platform/` 与打包资源只会打印 "unable to find directory entry" 警告，不影响构建；依赖该资源包的
  上游地图样式用不了，所以本 fork 把 MapLibre 指向公开免密钥的矢量样式
  （`https://tiles.openfreemap.org/styles/positron`），控件仍然是上游那套。
- **release 包通知**：R8 的资源收缩会把只被 Dart 字符串引用的 `ic_notification_icon` 裁掉，导致旧 release 包渠道建了却
  永远不显示。现已 `isShrinkResources = false`，并用 `res/raw/keep.xml` 钉住图标 —— 实测往 ntfy 主题发一条消息，
  release 包能在通知栏收到（见上方截图）。
- `--split-per-abi` 产出 `app-armeabi-v7a-release.apk`、`app-arm64-v8a-release.apk`、`app-x86_64-release.apk`，
  每个 77–83 MB；debug 版因为带符号会到 180–210 MB。
- **已知限制**：ntfy 长连接只在 App 进程活着时有效，被系统杀掉后请用 ntfy 客户端订阅同一主题兜底；
  Kotlin 前台服务尚未实现。

### 未入库的二进制素材

启动器图标 / 通知小图标 / 应用内图标都是**本地生成的 PNG**（二进制，且属于自制美术，不属于上游设计系统），
没有放进本仓库；请自行放到 `app/android/app/src/main/res/` 下（`ic_launcher`、`ic_launcher_round`、
`ic_notification_icon`）。其余构建所需文件都在仓库里。

### 推送服务端

`tool/quake-push/pusher.py` 是本 fork 实际使用的轮询脚本（任意小 VPS + Python 3.12，只用标准库）。
它把 markdown 消息发布到 ntfy 主题，服务器 / 主题 / 阈值都是环境变量。

## 许可证与致谢

- 上游：**EQMonitor**，MIT License，Copyright (c) 2026 Ryotaro Onoue — <https://github.com/YumNumm/EQMonitor>
- 本 fork 原样保留上游 `LICENSE`；本仓库新增文件同样以 MIT 发布。
- 设计系统、UI 组件与视觉识别均为上游成果，完整署名见根目录 `THIRD-PARTY-NOTICES.md`。
- 与 EQMonitor、USGS、NOAA、JMA 均无隶属关系，纯个人非官方构建。
