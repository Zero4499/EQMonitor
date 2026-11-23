# QuakePush

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B.svg)](https://flutter.dev)
[![Release](https://img.shields.io/badge/Release-v3.0.1%20(build%204014)-orange.svg)](https://github.com/Zero4499/EQMonitor/releases/tag/quakepush-v3.0.1)
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
| `QuakePush-3.0.1-2014-arm64-v8a.apk` | 2016 年以降のほぼすべての端末（Redmi K80 / HyperOS 含む） | 85.5 MB |
| `QuakePush-3.0.1-2014-armeabi-v7a.apk` | 古い 32-bit ARM 端末 | 82.0 MB |
| `QuakePush-3.0.1-2014-x86_64.apk` | エミュレータ専用 | 87.8 MB |

3 パッケージは同一のアプリ ID を共有するので、1 つだけインストールしてください。

```bash
adb install -r QuakePush-3.0.1-2014-arm64-v8a.apk
```

署名付き release ビルドです（`isMinifyEnabled = true`、`isShrinkResources = false`）。

## 機能

- **全球地震フィード**: USGS `all_day.geojson`。イベント ID で重複排除し、1 回の地震につき 1 回だけ鳴ります。
- **津波速報**: tsunami.gov（PTWC / NTWC）Atom フィード。地図上では速報を中空の等級別リング + 三本の波グリフで表示し、同じイベントが 2 通の速報で報じられた場合は 1 つのマーカーにまとめます。
- **2 系統のプッシュ経路**:
  1. 私の小さなサーバーが `tool/quake-push/pusher.py` を動かし、両フィードをポーリングして ntfy トピックに配信。アプリはそれを購読します。
  2. アプリ自体も USGS と tsunami.gov を直接ポーリング（地震 90 秒 / 津波 180 秒）。サーバーが落ちても受信できます。
- **ホームのライブ更新**: リストと地図はそのポーリング間隔で自動更新され、ホームのヘッダーに最終同期時刻の「更新 HH:mm:ss」が表示されます。
- **USGS イベントページ風の地図**: The National Map が配信する USGS Topo ラスター地図（API キー不要）をベースに、USGS GHSC のプレート境界をオフライン同梱の GeoJSON オーバーレイで重ねています。震源はマグニチュードで色と大きさが変わり、タップすると詳細シートが開きます。有効な速報が届くと、カメラは一度だけその地点へ移動します。
- **アプリ内アップデート確認**: このリポジトリの最新 GitHub Release を取得し versionCode を比較します。新しいビルドがあればダイアログを出し、ブラウザでダウンロードページを開きます。アプリ内で APK をダウンロード・インストールすることはありません。
- **プッシュ条件を自分で設定**: 最小マグニチュード（M2.5 / M4.5 / M6.0）、津波レベル（全速報 / 注意報以上 / 警報のみ）、警報級のみ。どの設定でも M7+、PAGER red、津波 Warning/Threat は必ず通ります — このアプリの目的はそこです。
- **3 言語 UI**: 简体中文 / English / 日本語。設定で切り替え、即時反映・再起動後も保持されます。
- **自前の通知チャンネルだけ残す**: 地震 M7 未満 / M7.0–7.9 / M8.0+ / 津波 / アラート級 / フォールバックの 6 チャンネル。それぞれ専用の LED 色と振動パターンを持ちます。チャンネル自体は無音で、提示音はアプリ側のネイティブ MediaPlayer が通知音量で再生します。上流および旧来のチャンネルは起動時に削除され、アップグレード後も EQ の残りチャンネルで画面が埋まりません。
- **設定ページの通知エリアは 2 項目だけ**: 1 つは全権限をまとめて許可（通知、全画面 intent、サイレントモードアクセス、バッテリー除外）、もう 1 つは通知テスト（エンドツーエンド / ローカル / 警報レベル）をプッシュテストパネルから実行します。
- **サイレントモード例外**: 通知ポリシーアクセスを申請し、許可後に通知チャンネルを作り直すことで、地震・津波警報がサイレントモード中も割り込めるようにします。

## スクリーンショット

Redmi K80（Android 17、HyperOS）の release ビルド実機キャプチャで、モックアップではありません。[`docs/screenshots.md`](./docs/screenshots.md) を参照してください。

## 実際に動かしてみたこと / ハマった点

Redmi K80（Android 17、HyperOS）で確認しました: USGS Topo ベースマップが描画され、海溝沿いにプレート境界線が見え、両経路とも接続済み、USGS イベントがプロットされ、ドットをタップするとシートが開き、初回起動の権限ダイアログが順に出て、フィルタ設定は再起動後も保持され、ntfy メッセージが通知欄に実際に表示され、津波リングと波グリフが速報の震源上に描画され、ホームの時刻表示は更新ごとに進みます。

ハマった点:

- **release で通知が出ない**: R8 が `ic_notification_icon` を未使用と判断して剥がしました（Dart の文字列からしか参照されていないため）。`isShrinkResources = false` と `res/raw/keep.xml` の keep ルールで固定しています。
- **バックグラウンド死亡**: Android はプロセスを容赦なく殺します。バッテリー除外と自動起動許可が生存の鍵です。
- **チャンネルの音**: 国内 ROM（特に HyperOS）は通知チャンネルに設定したカスタム着信音を無視することが多く、チャンネル設定画面では「音: なし」と表示されます。そのためチャンネルは意図的に無音とし、提示音はアプリ側で再生しています。
- **サイレントモードアクセス**: Manifest に `ACCESS_NOTIFICATION_POLICY` を宣言しないと、システムの「Modes access / 許可アプリ」リストにアプリ自体が現れません。既存チャンネルの `bypassDnd` は後から変更できないため、権限付与後にチャンネルを削除・再作成しています。
- **ベースマップの遍歴**: 上流の地図スタイルは `assets/platform` アセットパックを必要とし、スタンドアロンのフォークには無いため `AssetPackNotReadyException` が飛びます。CARTO ラスターは API キー必須、OSM 公式ラスターは各国のラベルが同時に重なり、OpenFreeMap ベクタースタイルは多言語地名を内包していました。最終的に USGS イベントページと同じ USGS Topo ラスターに落ち着いています。
- **`const new._()` はプライベート名前付きコンストラクタとして不正 Dart** です。`const X._()` と書く必要があります。このフォークで何度も踏みました。

**未検証**: ロック画面全画面 intent の専用スクリーンショットはなく、Kotlin フォアグラウンドサービスもありません — ntfy の長期接続はプロセスが生きている間だけ有効です。

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
- release APK は 82–88 MB、debug は約 385 MB です。

## コミュニティ

- Discord: <https://discord.gg/wW6tXzSdpv>

## 謝辞

- 上流 **EQMonitor**（MIT、© 2026 Ryotaro Onoue）: <https://github.com/YumNumm/EQMonitor>。`LICENSE` はそのまま保持し、ここに追加したファイルも MIT です。
- ベースマップ: U.S. Geological Survey, The National Map（USGSTopo）。プレート境界: USGS GHSC `Plate_Boundaries`。
- UI、デザインシステム、ビジュアルアイデンティティは上流の成果です。完全な帰属表示は `THIRD-PARTY-NOTICES.md` にあります。
- EQMonitor、USGS、NOAA、JMA とは無関係の個人ビルドです。公式の警戒システムとして依存しないでください。
