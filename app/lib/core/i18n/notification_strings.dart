import 'package:eqmonitor/core/i18n/app_strings.dart';

/// 通知文案三语收口。
///
/// 通知由后台轮询 / ntfy 回调弹出，拿不到 BuildContext，不能走
/// `appStringsProvider`，因此这里直接读静态语言设置，按当前 App 语言出文案。
String _lang() => AppLocaleSetting.value.languageCode;

String _pick(String zh, String en, String ja) => switch (_lang()) {
  'en' => en,
  'ja' => ja,
  _ => zh,
};

// ---------------------------------------------------------------------------
// 地震（第二链路直连）
// ---------------------------------------------------------------------------

String notifQuakeMajorTitle(String magnitudeLabel, String place) => _pick(
      '🚨 $magnitudeLabel 强震：$place',
      '🚨 $magnitudeLabel strong quake: $place',
      '🚨 $magnitudeLabel 強い地震: $place',
    );

String notifQuakeNormalTitle(String magnitudeLabel, String place) => _pick(
      '🌍 $magnitudeLabel 地震：$place',
      '🌍 $magnitudeLabel earthquake: $place',
      '🌍 $magnitudeLabel 地震: $place',
    );

String notifQuakeBody(String time, String url) => _pick(
      '时间 $time\n来源 USGS 直连（第二链路）\n$url',
      'Time $time\nSource USGS direct feed (link 2)\n$url',
      '時刻 $time\nソース USGS 直結（第 2 経路）\n$url',
    );

// ---------------------------------------------------------------------------
// 海啸公报（第二链路直连）
// ---------------------------------------------------------------------------

String notifTsunamiSevereTitle(String title) => _pick(
      '🚨 海啸警报：$title',
      '🚨 Tsunami warning: $title',
      '🚨 津波警報：$title',
    );

String notifTsunamiNormalTitle(String title) => _pick(
      '🌊 海啸公报：$title',
      '🌊 Tsunami bulletin: $title',
      '🌊 津波情報：$title',
    );

String notifTsunamiBody(String link) => _pick(
      '来源 tsunami.gov 直连（第二链路）\n$link',
      'Source tsunami.gov direct feed (link 2)\n$link',
      'ソース tsunami.gov 直結（第 2 経路）\n$link',
    );

// ---------------------------------------------------------------------------
// 测试通知
// ---------------------------------------------------------------------------

String notifFallbackQuakeTitle() => _pick(
      'USGS 地震情报',
      'USGS quake feed',
      'USGS 地震情報',
    );

String notifLocalTestTitle() => _pick(
      '🧪 本地通知测试',
      '🧪 Local notification test',
      '🧪 ローカル通知テスト',
    );

String notifLocalTestBody(String time) => _pick(
      '这条通知没有经过网络。\n能看到它说明通知权限和通道正常。\n时间 $time',
      'This notification did not go through the network.\n'
          'If you see it, notification permission and channels are OK.\n'
          'Time $time',
      'この通知はネットワークを通りません。\n'
          '表示されていれば通知権限とチャンネルは正常です。\n'
          '時刻 $time',
    );

String notifAlertTestTitle() => _pick(
      '🚨 警报级测试：M7.0 地震 / 海啸警报',
      '🚨 Alert test: M7.0 quake / tsunami warning',
      '🚨 アラート級テスト: M7.0 地震 / 津波警報',
    );

String notifAlertTestBody(String time) => _pick(
      '这是警报级通知测试（不会真发生地震）。\n'
          '样式：全屏弹出 + 闹钟音量 + 持续通知，关掉 App 或锁屏也会出现在锁屏上。\n'
          '真实触发条件：USGS M7+ / PAGER red，或 tsunami.gov Warning・Threat。\n'
          '时间 $time',
      'This is an alert-level test (no real earthquake).\n'
          'Style: full screen + alarm volume + ongoing notification; it stays on '
          'the lock screen even if the app is closed.\n'
          'Real triggers: USGS M7+ / PAGER red, or tsunami.gov Warning・Threat.\n'
          'Time $time',
      'これはアラート級通知のテストです（実際の地震ではありません）。\n'
          'スタイル: 全画面 + アラーム音量 + 常駐通知。アプリを閉じてもロック画面に残ります。\n'
          '実際の発動条件: USGS M7+ / PAGER red、または tsunami.gov Warning・Threat。\n'
          '時刻 $time',
    );

String notifE2eTitle() => _pick(
      '🧪 QuakePush 推送测试',
      '🧪 QuakePush push test',
      '🧪 QuakePush プッシュテスト',
    );

String notifE2eMessage(String time) => _pick(
      '**端到端链路测试**\n云主机 quake-pusher → ntfy.sh → App 订阅流\n时间 $time',
      '**End-to-end link test**\nServer quake-pusher → ntfy.sh → app subscription\nTime $time',
      '**エンドツーエンド経路テスト**\nサーバー quake-pusher → ntfy.sh → アプリ購読ストリーム\n時刻 $time',
    );
