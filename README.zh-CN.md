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

## 与上游的差异

| 项目 | 上游 EQMonitor | 本 fork（地震海啸推送） |
| --- | --- | --- |
| 数据源 | 日本气象厅地震情報 / 紧急地震速报（私有后端） | **USGS** `all_day.geojson`（全球）+ **tsunami.gov** Atom（NOAA） |
| 推送方式 | 上游私有后端 + FCM | **ntfy 主题**（链路 1）+ **App 内直连轮询**（链路 2） |
| 通知渠道 | 上游渠道 | `global_earthquake`、`global_tsunami`、`global_alert`（全屏 + 闹钟级） |
| 包名 | `net.yumnumm.eqmonitor` | **`sbs.ourstv.quakepush`**（自建签名，与官方签名不同） |
| 界面语言 | 日文为主 | **运行时可切换：简体中文 / English**（持久保存） |
| 页面 | 日本向地图 / 紧急地震速报 / 震度 | 推送状态首页、**地震列表（按震级分级配色）**、**海啸公报列表**、精简设置 |
| Debug 标识 | debug 包显示 DEBUG 丝带与版本角标 | 已移除，debug 包外观与正式版一致 |
| 后端依赖 | 需要私有 `eqmonitor-backend` | **不需要任何后端**，只用公开数据源 |

表格以外的内容（设计系统、整体观感、设置页骨架、关于/声明组件、图标生成管线）均为上游代码，尽量保持原样。

---

## 功能

- **双链路推送**
  1. **云主机 → ntfy**：云上一个小 Python 轮询脚本（`tool/quake-push/pusher.py`）把 USGS + tsunami.gov 的结果发布到
     ntfy 主题，App 用 `dart:io` 的 HTTP NDJSON 流订阅（断线指数退避 2 s → 60 s）。
  2. **App 直连官方源**：App 自己轮询 USGS `all_day.geojson`（90 s）与 tsunami.gov `PHEBAtom.xml` / `PAAQAtom.xml`
     （180 s），按事件 id 去重后本地弹通知。云主机或 ntfy 挂了也能收。两条链路互相去重，同一事件不会重复提醒。
- **警报级通知**：震级 ≥ 7、PAGER 为 red、或海啸 `Warning` / `Threat` 走 `global_alert` 渠道
  （importance 最高、`USAGE_ALARM`、`category=alarm`、常驻、带 `fullScreenIntent`）。
- **事件列表**：地震 Tab 按震级分档配色（灰蓝 → 蓝 → 绿 → 金黄 → 橙 → 橙红 → 红），顶部带颜色图例，
  显示 PAGER 与海啸评估、点击弹详情；海啸 Tab 按公报级别配色（Warning/Threat 红、Watch/Advisory 橙、Information 蓝）。
- **界面语言切换**（中文 / 英文），在设置页即时生效，写入 `shared_preferences`。
- **澎湃 OS / MIUI 适配**：渠道补非空描述、`showBadge`、ticker 文案，并提供直达系统通知渠道设置页的入口。

## 截图

以下是本 fork 模拟器实截（1080 × 2400，Pixel 6 / Android 16），**不是效果图**；界面布局与视觉风格来自上游 EQMonitor：

| 首页（推送状态） | 地震列表（分级配色 + 图例） | 海啸公报 |
| --- | --- | --- |
| ![home](docs/screenshots/home.png) | ![quake list](docs/screenshots/list-earthquake.png) | ![tsunami](docs/screenshots/list-tsunami.png) |

| 设置页（语言切换） | 英文界面首页 | 新图标 |
| --- | --- | --- |
| ![settings](docs/screenshots/settings.png) | ![english](docs/screenshots/home-en.png) | ![icon](docs/screenshots/icon.png) |

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
# 在 app/ 目录
flutter pub get
flutter build apk --debug \
  --dart-define=FLAVOR=dev \
  --dart-define=REST_API_URL=https://dev.v2.api.eqmonitor.app \
  --dart-define=WS_API_URL=wss://dev.v2.api.eqmonitor.app/ws \
  --dart-define=APP_NAME=QuakePush \
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
- 缺 `assets/platform/` 与打包资源只会打印 "unable to find directory entry" 警告，不影响构建；地图/AssetPack
  功能不在本 fork 范围内。
- **release（开 R8）在这台设备上本地通知不弹**（渠道已建、service 报 connected，但 `show()` 不显示）；
  debug 正常，所以发布的是去掉 debug 标识的 debug 包。
- **已知限制**：ntfy 长连接只在 App 进程活着时有效，被系统杀掉后请用 ntfy 客户端订阅同一主题兜底；
  Kotlin 前台服务尚未实现。

### 未入库的二进制素材

启动器图标 / 通知小图标 / 应用内图标都是**本地用脚本生成的 PNG**（构建工作区里的 `make-icon*.ps1`），
没有放进本仓库；请自行重新生成或换成你自己的图。其余构建所需文件都在仓库里。

### 推送服务端

`tool/quake-push/pusher.py` 是本 fork 实际使用的轮询脚本（任意小 VPS + Python 3.12，只用标准库）。
它把 markdown 消息发布到 ntfy 主题，服务器与主题在文件顶部可改。

## 许可证与致谢

- 上游：**EQMonitor**，MIT License，Copyright (c) 2026 Ryotaro Onoue — <https://github.com/YumNumm/EQMonitor>
- 本 fork 原样保留上游 `LICENSE`；本仓库新增文件同样以 MIT 发布。
- 设计系统、UI 组件与视觉识别均为上游成果，完整署名见根目录 `THIRD-PARTY-NOTICES.md`。
- 与 EQMonitor、USGS、NOAA、JMA 均无隶属关系，纯个人非官方构建。
