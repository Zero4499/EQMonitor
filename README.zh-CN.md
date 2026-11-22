# QuakePush

先说清楚：**这份文档、下面的代码改动、以及仓库里的 release 说明，都是 AI（豆包办公模式的 Agent）按我的要求写的，我没逐字校对。**
跟代码对不上的地方，以代码为准。

界面也不是我画的 —— 布局、设计系统、组件、动效全是上游 [EQMonitor](https://github.com/YumNumm/EQMonitor) 的，我只是在它上面换功能层。

[English](./README.md) | 简体中文

---

## 这是个什么

我把 EQMonitor v3.0.1 fork 过来，把原来只服务日本气象厅的那套数据源换掉：地震用 **USGS** 的全球数据，海啸用 **tsunami.gov** 的公报，
再加一条完全不依赖服务器的推送。包名改成 `sbs.ourstv.quakepush`，应用名只有 `QuakePush` 一个。

上游是 MIT，© 2026 Ryotaro Onoue。UI 的功劳全归上游作者，我这边只动了数据和功能。

## 装哪个

Release 页：<https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1>

| 文件 | 适合谁 | 体积 |
| --- | --- | --- |
| `QuakePush-v3.0.1-arm64-v8a.apk` | 2016 年之后的手机基本都是（红米 K80 / 澎湃 OS 也行） | 80.5 MB |
| `QuakePush-v3.0.1-armeabi-v7a.apk` | 老一点的 32 位 ARM 设备 | 77.1 MB |
| `QuakePush-v3.0.1-x86_64.apk` | 只在模拟器上用 | 82.7 MB |

三个包共用同一个包名，装一个就行：

```bash
adb install -r QuakePush-v3.0.1-arm64-v8a.apk
```

都是签名 release 包（`isMinifyEnabled = true`，`isShrinkResources = false`）。debug 包只为了调日志，扔在 CDN 上：
[arm64-v8a](https://aka.doubaocdn.com/s/GTPFIZLDUH) ·
[armeabi-v7a](https://aka.doubaocdn.com/s/6y0k20HsFV) ·
[x86_64](https://aka.doubaocdn.com/s/eIHRbiqGqO)。

## 干掉了什么、加了什么

- **数据**：上游的日本气象厅地震情報 / 紧急地震速报 → USGS `all_day.geojson` + tsunami.gov Atom。私有后端不再需要。
- **推送**：两条链路并存，一是我自己那台小机器跑 `tool/quake-push/pusher.py` 轮询后发到 ntfy 主题，App 订阅；二是 App 自己直连 USGS 和 tsunami.gov 轮询（90 s / 180 s）。按事件 id 去重，同一件事只响一次。
- **通知渠道只留自己的**：`global_earthquake`（地震）、`global_tsunami`（海啸公报）、`global_alert`（警报级）、`service_fallback`（兜底）。
  上游那 22 个渠道（`eew_*`、`tsunami_*`、`VXSE*` 之类）在启动时逐个删掉，升级上来的人也不会再看到一屏 EQ 的旧渠道。
- **首启一次把权限要全**：通知、全屏 intent、精确闹钟、勿扰访问、电池优化白名单，五个一起弹。设置页里还能再点一次重来。
  （国产 ROM 不把电池白名单放过，后台进程被杀就收不到推送，这条是必需的。）
- **推送条件可以自己定**：最小震级（M2.5 / M4.5 / M6.0）、海啸级别（全部公报 / 关注级以上 / 只要警报）、只推警报级。
  无论怎么设，M7+、PAGER red、海啸 Warning/Threat 这三种永远放行 —— 毕竟这是拿来防身的。
- **首页就是地图**：整屏 MapLibre，底图换成浅灰的矢量样式（Positron，OpenFreeMap 提供，免密钥，页脚挂 OSM/OpenFreeMap 署名）。
  震中按震级上色、按震级放大；**点一下那张圆点，直接弹出这条事件的详情**，跟列表里点条目用的是同一个弹层。
- **开屏不放图了**：以前那张 Q 渐变图去掉了，冷启动就是一屏跟地图同色的浅灰，直接进首页。
- **语言**：简体中文 / English，设置里切换，立即生效、重启保持。
- **其他**：上游的 DEBUG 丝带已移除；小图标、启动器图标都是我自己的 Q 标志（本地生成的 PNG，没进 git）。

## 实测与踩过的坑

模拟器（Android 16，1080×2400）上反复装 release 包跑过：地图出图、两条链路都显示已连接、约 200 条 USGS 事件上图、
点圆点弹详情、首启权限弹窗依次出现、推送条件改完重启还在、ntfy 发一条消息通知栏真能弹（小图标是 Q）。

踩过的几个坑，省得你也踩：

- **release 包不弹通知**：R8 把 `ic_notification_icon` 当无用资源裁了（它只被 Dart 字符串引用）。现在 `isShrinkResources = false`，外加 `res/raw/keep.xml` 钉住图标。
- **后台被杀**：安卓默认会挨后台，必须电池白名单 + 允许自启动才稳。
- **地图样式**：上游地图依赖 `assets/platform` 资源包，独立 fork 里没有，直接用会 `AssetPackNotReadyException`。
  CARTO 那种栅格要 API key（不然满屏 “API KEY REQUIRED”）；OSM 官方栅格能出图，但各国文字全糊在一张图上，脏得没法看 —— 最后用了矢量 Positron。
- **`const new._()` 这种私有命名构造是非法的**，得写 `const X._()`，这行我在这份 fork 里改了好几次。

**没验证的**：没在真机上跑过（手上没插线），锁屏全屏 intent 没截图取证，也没有 Kotlin 前台服务 —— ntfy 那条长连接只在进程活着时有效。

## 截图

都是 release 包实跑的截图，不是效果图。

| 地图首页 | 点圆点看详情 | 面板拉满 | 设置页 |
| --- | --- | --- | --- |
| ![首页](https://aka.doubaocdn.com/s/qib1sLwVZD) | ![详情](https://aka.doubaocdn.com/s/TAES3qdXYf) | ![面板](https://aka.doubaocdn.com/s/J6aSOQBnNm) | ![设置](https://aka.doubaocdn.com/s/JY6X8v9jtE) |

图标（蓝渐变底 + 白圈 Q）：
![icon](https://aka.doubaocdn.com/s/x5COitJjsV)

更多画面见 [`docs/screenshots.md`](./docs/screenshots.md)。

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
- 缺 `assets/platform/` 只会刷 “unable to find directory entry” 警告，不影响编译。
- release 包 77–83 MB，debug 180–210 MB。

## 谢谢你读到这里

- 上游 **EQMonitor**（MIT，© 2026 Ryotaro Onoue）：<https://github.com/YumNumm/EQMonitor>。`LICENSE` 原样保留，这里新增的文件也走 MIT。
- UI、设计系统、视觉识别都是上游的成果，完整署名在 `THIRD-PARTY-NOTICES.md`。
- 跟 EQMonitor、USGS、NOAA、JMA 都没关系，纯个人非官方构建，别拿去当官方预警用。
