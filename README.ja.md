# QuakePush

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B.svg)](https://flutter.dev)
[![Release](https://img.shields.io/badge/Release-v3.0.1-orange.svg)](https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1)
[![Discord](https://img.shields.io/badge/Discord-join%20chat-5865F2?logo=discord&logoColor=white)](https://discord.gg/wW6tXzSdpv)

> **最初に断っておきます:** この README、リリースノート、コードの変更群は、依頼を受けて AI アシスタント（Doubao / 豆包 ワークモードの Agent）が書いたもので、私は一行ずつ校正していません。文章とコードが食い違う場合は、コードを優先してください。

UI も私のものではありません — レイアウト、デザインシステム、コンポーネント、アニメーションはすべて上流の [EQMonitor](https://github.com/YumNumm/EQMonitor) からのもので、機能層だけ差し替えています。

[English](./README.md) · [简体中文](./README.zh-CN.md) · 日本語

---

## これは何か

EQMonitor v3.0.1 のフォークです。JMA 専用だったデータ経路を抜き出し、地震は **USGS** の全球データ、津波は **tsunami.gov** の速報に置き換え、サーバー不要の第二のプッシュ経路を追加しました。アプリ ID は `sbs.ourstv.quakepush`、アプリ名は `QuakePush` のみです。

上流は MIT ライセンス、© 2026 Ryotaro Onoue。UI のクレジットはすべて上流作者に帰属します。

## どれを入れるか

リリースページ: <https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1>

| ファイル | 対象 | サイズ |
| --- | --- | --- |
| `QuakePush-v3.0.1-arm64-v8a.apk` | 2016 年以降のほぼすべての端末（Redmi K80 / HyperOS 含む） | 80.6 MB |
| `QuakePush-v3.0.1-armeabi-v7a.apk` | 古い 32-bit ARM 端末 | 77.2 MB |
| `QuakePush-v3.0.1-x86_64.apk` | エミュレータ専用 | 82.8 MB |

3 パッケージは同一のアプリ ID を共有するので、1 つだけインストールしてください。

```bash
adb install -r QuakePush-v3.0.1-arm64-v8a.apk
```

署名付き release ビルドです（`isMinifyEnabled = true`、`isShrinkResources = false`）。

## 機能

- **全球地震フィード**: USGS `all_day.geojson`。イベント ID で重複排除し、1 回の地震につき 1 回だけ鳴ります。
- **津波速報**: tsunami.gov（PTWC / NTWC）Atom フィード。Warning / Watch / Information で色分けされます。
- **2 系統のプッシュ経路**:
  1. 私の小さなサーバーが `tool/quake-push/pusher.py` を動かし、両フィードをポーリングして ntfy トピックに配信。アプリはそれを購読します。
  2. アプリ自体も USGS と tsunami.gov を直接ポーリング（90 秒 / 180 秒）。サーバーが落ちても受信できます。
- **USGS イベントページ風の地図**: The National Map が配信する USGS Topo ラスター地図（API キー不要）をベースに、USGS GHSC のプレート境界をオフライン同梱の GeoJSON オーバーレイで重ねています。震源はマグニチュードで色と大きさが変わり、タップすると詳細シートが開きます。
- **プッシュ条件を自分で設定**: 最小マグニチュード（M2.5 / M4.5 / M6.0）、津波レベル（全速報 / 注意報以上 / 警報のみ）、警報級のみ。どの設定でも M7+、PAGER red、津波 Warning/Threat は必ず通ります — このアプリの目的はそこです。
- **3 言語 UI**: 简体中文 / English / 日本語。設定で切り替え、即時反映・再起動後も保持されます。
- **サイレントモード例外**: 通知ポリシーアクセスを申請し、許可後に通知チャンネルを作り直すことで、地震・津波警報がサイレントモード中も割り込めるようにします。
- **自前の通知チャンネルだけ残す**: `global_earthquake`、`global_tsunami`、`global_alert`、`service_fallback`。上流のチャンネル（`eew_*`、`tsunami_*`、`VXSE*` など）は起動時に削除され、アップグレード後も EQ の残りチャンネルで画面が埋まりません。
- **初回起動でまとめて権限申請**: 通知、全画面 intent、正確アラーム、サイレントモードアクセス、バッテリー最適化除外。設定ページからやり直すボタンもあります。バッテリー除外を省くと ROM にプロセスを殺されてプッシュが届かなくなるため、これは任意では済まません。

## スクリーンショット

Android 16 エミュレーター（1080×2400）の release ビルド実機キャプチャで、モックアップではありません。

| ホーム — 简体中文 | ホーム — English | ホーム — 日本語 |
| --- | --- | --- |
| ![Chinese home](https://aka.doubaocdn.com/s/h5tWil2Jgf) | ![English home](https://aka.doubaocdn.com/s/twV3Fkc0VF) | ![Japanese home](https://aka.doubaocdn.com/s/z3kidghnsa) |

| 設定 | イベント詳細 | プッシュテストパネル |
| --- | --- | --- |
| ![Settings](https://aka.doubaocdn.com/s/bQ7CnjVqhU) | ![Detail](https://aka.doubaocdn.com/s/D9LjOqSo55) | ![Push panel](https://aka.doubaocdn.com/s/WIqnLppTbO) |

その他のキャプチャは [`docs/screenshots.md`](./docs/screenshots.md) にあります。

## 実際に動かしてみたこと / ハマった点

Android 16 エミュレーター（1080×2400）で release パッケージを繰り返しインストールして確認しました: USGS Topo ベースマップが描画され、海溝沿いにプレート境界線が見え、両経路とも接続済み、約 200 件の USGS イベントがプロットされ、ドットをタップするとシートが開き、初回起動の権限ダイアログが順に出て、フィルタ設定は再起動後も保持され、ntfy メッセージが通知欄に Q アイコン付きで実際に表示されました。

ハマった点:

- **release で通知が出ない**: R8 が `ic_notification_icon` を未使用と判断して剥がしました（Dart の文字列からしか参照されていないため）。`isShrinkResources = false` と `res/raw/keep.xml` の keep ルールで固定しています。
- **バックグラウンド死亡**: Android はプロセスを容赦なく殺します。バッテリー除外と自動起動許可が生存の鍵です。
- **サイレントモードアクセス**: Manifest に `ACCESS_NOTIFICATION_POLICY` を宣言しないと、システムの「Modes access / 許可アプリ」リストにアプリ自体が現れません。既存チャンネルの `bypassDnd` は後から変更できないため、権限付与後にチャンネルを削除・再作成しています。
- **ベースマップの遍歴**: 上流の地図スタイルは `assets/platform` アセットパックを必要とし、スタンドアロンのフォークには無いため `AssetPackNotReadyException` が飛びます。CARTO ラスターは API キー必須（無いと画面いっぱいに "API KEY REQUIRED"）、OSM 公式ラスターは各国のラベルが同時に重なり、OpenFreeMap ベクタースタイルは多言語地名を内包していました。最終的に USGS イベントページと同じ USGS Topo ラスターに落ち着いています。
- **`const new._()` はプライベート名前付きコンストラクタとして不正 Dart** です。`const X._()` と書く必要があります。このフォークで何度も踏みました。

**未検証**: 実機での動作確認なし（端末を繋いでいない）、ロック画面全画面 intent のスクリーンショットなし、Kotlin フォアグラウンドサービスもありません — ntfy の長期接続はプロセスが生きている間だけ有効です。

## ビルドするには

Flutter 3.47 / Dart 3.x、JDK 17、Android SDK 36。`app/android/` 配下に自分の keystore を指す `key.properties` を置いてください（テンプレート: `app/android/key.properties.example`）。

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

- 上流のバックエンド URL はここでは未使用ですが、上流のブートストラップコードが読むためプレースホルダを渡してください。
- `app/environment/environment` は上流のシンボリックリンクで `.env` が無いため、設定はすべて `--dart-define` で注入します。
- `assets/platform/` が無くても "unable to find directory entry" 警告だけで、ビルドは壊れません。
- release APK は 77–83 MB、debug は 180–210 MB です。

## コミュニティ

- Discord: <https://discord.gg/wW6tXzSdpv>

## 謝辞

- 上流 **EQMonitor**（MIT、© 2026 Ryotaro Onoue）: <https://github.com/YumNumm/EQMonitor>。`LICENSE` はそのまま保持し、ここに追加したファイルも MIT です。
- ベースマップ: U.S. Geological Survey, The National Map（USGSTopo）。プレート境界: USGS GHSC `Plate_Boundaries`。
- UI、デザインシステム、ビジュアルアイデンティティは上流の成果です。完全な帰属表示は `THIRD-PARTY-NOTICES.md` にあります。
- EQMonitor、USGS、NOAA、JMA とは無関係の個人ビルドです。公式の警戒システムとして依存しないでください。
