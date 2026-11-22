# QuakePush · 地震海啸推送

> ### ⚠️ 本文档由 AI 撰写
> **本仓库所有 Markdown —— 这份 README、`README.zh-CN.md`、`docs/screenshots.md` 以及 GitHub release 说明 —— 都是 AI（豆包办公模式 Agent）按维护者要求写的，不是人写的。**
> 本 fork 的代码改动（数据源、推送链路、分级配色、地图首页、多语言、release 构建修复）同样由这个 AI 在同样的会话里完成，
> 完成后经过编译、安裝、实际运行验证。
> 所以：下面的事实描述对应的是**实际构建并观察到的东西**，但文字本身**没有经过人工逐行校对**。拿去用之前请自己核实。
>
> AI 没有做的事：没有自己发明 UI。布局、设计系统、组件、动效、设置页骨架全部是上游
> [EQMonitor](https://github.com/YumNumm/EQMonitor) 的代码。

[English](./README.md) | 简体中文

一个 fork 自 **[EQMonitor](https://github.com/YumNumm/EQMonitor) v3.0.1** 的安卓客户端：把只服務日本的 JMA 数据源换成
**USGS**（全球地震）和 **NOAA / tsunami.gov**（海啸公报），再补一条完全不需要服务器的推送链路。

上游是 MIT 许可，© 2026 Ryotaro Onoue。**UI 的功劳全部属于上游作者**；这个 fork 只在那个界面之上换功能层。

---

## 下载

安装包已作为 GitHub Release 资产上传：
**<https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1>**

| 文件 | ABI | 体积 | 直链 |
| --- | --- | --- | --- |
| `QuakePush-v3.0.1-arm64-v8a.apk` | arm64-v8a —— 2016 年以后的手机基本都是（含红米 K80 / 澎湃 OS） | 80.5 MB | [下载](https://github.com/Zero4499/EQMonitor/releases/download/quakepush-v3.0.1/QuakePush-v3.0.1-arm64-v8a.apk) |
| `QuakePush-v3.0.1-armeabi-v7a.apk` | armeabi-v7a —— 较早的 32 位 ARM 设备 | 77.1 MB | [下载](https://github.com/Zero4499/EQMonitor/releases/download/quakepush-v3.0.1/QuakePush-v3.0.1-armeabi-v7a.apk) |
| `QuakePush-v3.0.1-x86_64.apk` | x86_64 —— 仅模拟器 | 82.6 MB | [下载](https://github.com/Zero4499/EQMonitor/releases/download/quakepush-v3.0.1/QuakePush-v3.0.1-x86_64.apk) |

签名 release 包（`isMinifyEnabled = true`、`isShrinkResources = false`）。三个包共用包名
`sbs.ourstv.quakepush`，只装一个：

```bash
adb install -r QuakePush-v3.0.1-arm64-v8a.apk
```

debug 包（每个 ABI 约 180–210 MB，只为了调试符号）还在 CDN：
[arm64-v8a](https://aka.doubaocdn.com/s/GTPFIZLDUH) ·
[armeabi-v7a](https://aka.doubaocdn.com/s/6y0k20HsFV) ·
[x86_64](https://aka.doubaocdn.com/s/eIHRbiqGqO)。

## 这个 fork 改了什么

| | 上游 EQMonitor | 这里 |
| --- | --- | --- |
| 数据 | 日本气象厅地震情報 / 紧急地震速报，走私有后端 | USGS `all_day.geojson`、tsunami.gov Atom |
| 推送 | 上游后端 + FCM | ntfy 主题 **加** App 内直连轮询，两边互相去重 |
| 通知渠道 | 上游那套 | `global_earthquake`、`global_tsunami`、`global_alert` |
| 包名 | `net.yumnumm.eqmonitor` | `sbs.ourstv.quakepush`，自建签名 |
| 语言 | 日文为主 | 简体中文 / English，运行时切换并持久保存 |
| 首页 | 地图铺满 + 可拖动面板 | 同样的 map-first，图层换成全球震中 |
| 后端 | 依赖私有 `eqmonitor-backend` | 不需要 —— 只用公开数据源 |
| Debug 标识 | debug 包带 DEBUG 丝带 | 已移除 |

## 怎么工作

- **地图即首页。** 整屏 MapLibre 地图，引擎与 `MapOptions` / `MapLibreMap` / `CircleStyleLayer` 用法都与上游一致。
  已加载的 USGS 事件画成圆圈，颜色和半径跟震级走。内容放在上游同款的 `DraggableScrollableSheet`
  （44% ⇄ 88%，带吸附）里浮在地图上：震级筛选 chips 带实时计数、双链路状态、最强三条、列表/设置入口、最近 20 条。
- **两条推送链路。** ① 小 VPS 跑 `tool/quake-push/pusher.py`，轮询 USGS + tsunami.gov 发到 ntfy 主题，App 用 `dart:io`
  订阅那条 NDJSON 流。② App 自己轮询同样的公开源（90 s / 180 s）。两边按事件 id 去重，同一事件只会提醒一次。
- **警报级。** M ≥ 7、PAGER red、或海啸 Warning/Threat 走 `global_alert`：最高 importance、闹钟用途、`category=alarm`、
  常驻、全屏 intent。
- **分级配色。** 地震：灰蓝 → 蓝 → 绿 → 金黄 → 橙 → 橙红 → 红，一档一级，配图例行，左侧色条 / 震级圈 / 箭头同色。
  海啸公报：Warning/Threat 红、Watch/Advisory 橙、Information 蓝。
- **界面语言。** 设置页可选简体中文 / English，即时生效，存在 `shared_preferences` 的 `app_ui_locale_v1`，
  直连链路的通知文案也跟着切。

## 实际验证过的

- release 包装在 Android 16 模拟器（1080 × 2400）上启动运行：地图出图、两条推送链路都报已连接、约 210 条 USGS 事件正常上图。
- **release 包能弹通知。** 往 ntfy 主题发一条消息，通知栏确实收到，小图标是本应用自己的 Q。之前 release 包不弹的真正原因：
  R8 资源收缩把 `ic_notification_icon` 当成没用的资源删了（它只被 Dart 字符串引用）。现在 `isShrinkResources = false`，
  并用 `res/raw/keep.xml` 钉住图标。
- 中英切换不用重启即生效，重启后也保持。
- 两个列表的行颜色与其档位一致；震级筛选把所有事件滤掉时，地图图层也随之空掉。

**没验证的**：没在真机（红米 K80）上跑过；锁屏全屏 intent 没取证；Kotlin 前台服务不存在 —— ntfy 长连接只在进程活着时有效。

## 截图

release 包真实运行画面，不是效果图。

| 地图首页 | release 包弹通知 | 面板拉到最高 | 设置页 |
| --- | --- | --- | --- |
| ![首页](https://aka.doubaocdn.com/s/21gV5dPhVC) | ![通知](https://aka.doubaocdn.com/s/oRd365wdRU) | ![面板](https://aka.doubaocdn.com/s/J6aSOQBnNm) | ![设置](https://aka.doubaocdn.com/s/JY6X8v9jtE) |

更多见 [`docs/screenshots.md`](./docs/screenshots.md)。启动器图标是自制标识（蓝色渐变方块 + 白色圆圈 Q），不是上游素材：
![icon](https://aka.doubaocdn.com/s/x5COitJjsV)

## 构建

Flutter 3.47 / Dart 3.x、JDK 17、Android SDK 36，以及在 `app/android/` 旁放 `key.properties` 指向你自己的密钥
（模板在 `app/android/key.properties.example`）。

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

上手前值得知道的坑：

- 上游后端地址本 fork 用不到，但上游启动代码依旧会读，所以照上面传占位值。
- 上游 `app/environment/environment` 是符号链接，`.env` 取不到，所有配置都靠 `--dart-define` 注入。
- 缺 `assets/platform/` 只会打 “unable to find directory entry” 警告。依赖该资源包的上游地图样式用不了，
  所以 MapLibre 指向公开免密钥样式 `https://tiles.openfreemap.org/styles/positron`，地图控件还是上游那套。
- `--split-per-abi` 出 77–83 MB 的 release 包；debug 版 180–210 MB。

启动器 / 通知 / 应用内图标都是本地生成的 PNG，**没进 git**（二进制且属于自制美术）。要自备
`ic_launcher`、`ic_launcher_round`、`ic_notification_icon` 放到 `app/android/app/src/main/res/`。构建所需的其余东西都在仓里。

## 致谢与许可

- 上游：**EQMonitor**，MIT，© 2026 Ryotaro Onoue — <https://github.com/YumNumm/EQMonitor>。`LICENSE` 原样保留，
  本仓库新增文件同样是 MIT。
- UI、设计系统与视觉识别：上游成果，完整署名见 `THIRD-PARTY-NOTICES.md`。
- 本 fork 的文档与代码改动：由 AI 按维护者要求完成，如本文开头所述。
- 与 EQMonitor、USGS、NOAA、JMA 均无隶属关系，纯个人非官方构建。
