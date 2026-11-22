import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePrefsKey = 'app_ui_locale_v1';

/// 界面语言（简体中文 / English / 日本語）。
class AppLocaleSetting {
  const AppLocaleSetting._();

  static Locale value = const Locale('zh', 'CN');

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localePrefsKey);
    if (raw == null) {
      return;
    }
    value = parse(raw);
  }

  static Future<void> save(Locale locale) async {
    value = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefsKey, encode(locale));
  }

  static String encode(Locale locale) =>
      '${locale.languageCode}_${locale.countryCode ?? ''}';

  static Locale parse(String raw) {
    final parts = raw.split('_');
    final language = parts.first;
    final country = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    return country == null ? Locale(language) : Locale(language, country);
  }
}

/// 当前界面语言。原先用 StateProvider，但本项目的 Riverpod 版本已移除该类，
/// 改用 Notifier 持有单一 Locale。
final appLocaleProvider =
    NotifierProvider<AppLocaleNotifier, Locale>(AppLocaleNotifier.new);

class AppLocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => AppLocaleSetting.value;

  Future<void> change(Locale locale) async {
    await AppLocaleSetting.save(locale);
    state = locale;
  }
}

/// 目前提供的界面语言。
const appSupportedLocales = <Locale>[
  Locale('zh', 'CN'),
  Locale('en', 'US'),
  Locale('ja', 'JP'),
];

final appStringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(appLocaleProvider);
  return AppStrings.of(locale);
});

class AppStrings {
  const AppStrings({
    required this.appTitle,
    required this.pushCardTitle,
    required this.bothLinksRunning,
    required this.bothLinksDown,
    required this.linkNtfy,
    required this.linkDirect,
    required this.eventListTitle,
    required this.eventListSubtitle,
    required this.mapTitle,
    required this.mapSubtitle,
    required this.settingsTitle,
    required this.settingsNotificationSection,
    required this.settingsNotificationTile,
    required this.settingsNotificationSubtitle,
    required this.settingsLanguage,
    required this.settingsAboutSection,
    required this.settingsAboutBody,
    required this.settingsVersionTag,
    required this.notificationPageTitle,
    required this.pushChannelSection,
    required this.systemSection,
    required this.systemChannelTile,
    required this.systemChannelSubtitle,
    required this.limitsSection,
    required this.limitsBody,
    required this.panelTitle,
    required this.link1Label,
    required this.link2Label,
    required this.e2eTest,
    required this.localTest,
    required this.alertTest,
    required this.openSystemNotificationSettings,
    required this.panelNote,
    required this.tabQuakes,
    required this.tabTsunami,
    required this.listEmptyQuakes,
    required this.listEmptyTsunami,
    required this.retry,
    required this.close,
    required this.loadFailedUsgs,
    required this.loadFailedTsunami,
    required this.detailTime,
    required this.detailPager,
    required this.detailTsunamiEval,
    required this.detailEventId,
    required this.valueYes,
    required this.valueNo,
    required this.valueNone,
    required this.timeUnknown,
    required this.pushTileTitle,
    required this.pushTileSubtitleNtfy,
    required this.sheetClose,
    required this.sheetServerLabel,
    required this.sheetTopicLabel,
    required this.e2eOk,
    required this.e2eFail,
    required this.localOk,
    required this.alertOk,
  });

  final String appTitle;
  final String pushCardTitle;
  final String bothLinksRunning;
  final String bothLinksDown;
  final String linkNtfy;
  final String linkDirect;
  final String eventListTitle;
  final String eventListSubtitle;
  final String mapTitle;
  final String mapSubtitle;
  final String settingsTitle;
  final String settingsNotificationSection;
  final String settingsNotificationTile;
  final String settingsNotificationSubtitle;
  final String settingsLanguage;
  final String settingsAboutSection;
  final String settingsAboutBody;
  final String settingsVersionTag;
  final String notificationPageTitle;
  final String pushChannelSection;
  final String systemSection;
  final String systemChannelTile;
  final String systemChannelSubtitle;
  final String limitsSection;
  final String limitsBody;
  final String panelTitle;
  final String link1Label;
  final String link2Label;
  final String e2eTest;
  final String localTest;
  final String alertTest;
  final String openSystemNotificationSettings;
  final String panelNote;
  final String tabQuakes;
  final String tabTsunami;
  final String listEmptyQuakes;
  final String listEmptyTsunami;
  final String retry;
  final String close;
  final String loadFailedUsgs;
  final String loadFailedTsunami;
  final String detailTime;
  final String detailPager;
  final String detailTsunamiEval;
  final String detailEventId;
  final String valueYes;
  final String valueNo;
  final String valueNone;
  final String timeUnknown;
  final String pushTileTitle;
  final String pushTileSubtitleNtfy;
  final String sheetClose;
  final String sheetServerLabel;
  final String sheetTopicLabel;
  final String e2eOk;
  final String e2eFail;
  final String localOk;
  final String alertOk;

  static AppStrings of(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return en;
      case 'ja':
        return ja;
      default:
        return zh;
    }
  }

  static const zh = AppStrings(
    appTitle: 'QuakePush',
    pushCardTitle: '地震 / 海啸推送',
    bothLinksRunning: '双链路运行中',
    bothLinksDown: '两条链路都断了',
    linkNtfy: '云主机 → ntfy',
    linkDirect: 'App 直连官方源',
    eventListTitle: '地震 / 海啸列表',
    eventListSubtitle: '最近 24 小时 USGS 地震 + tsunami.gov 公报',
    mapTitle: '全球地震地图',
    mapSubtitle: '世界底图 + 震中圆点，按震级着色',
    settingsTitle: '设置',
    settingsNotificationSection: '通知',
    settingsNotificationTile: '通知设置',
    settingsNotificationSubtitle: '推送通道、测试通知',
    settingsLanguage: '界面语言',
    settingsAboutSection: '关于',
    settingsAboutBody:
        'EQMonitor 原版（v3.0.1）+ ntfy 推送改造，界面与素材来自上游项目。\n'
        '数据来源：USGS 地震速报 / tsunami.gov 海啸公报（PTWC / NTWC）。\n'
        '上游项目：github.com/YumNumm/EQMonitor (MIT License)。',
    settingsVersionTag: '多语言改造版 · ntfy 推送',
    notificationPageTitle: '通知设置',
    pushChannelSection: '推送通道',
    systemSection: '系统',
    systemChannelTile: 'Android 通知渠道设置',
    systemChannelSubtitle: '管理横幅、锁屏显示与声音等系统级通知行为。',
    limitsSection: '限制与说明',
    limitsBody:
        'App 在前台时由本机保持长连接接收；被系统杀掉后，请用 ntfy 官方客户端订阅同一主题作为保底。',
    panelTitle: 'USGS / 海啸推送测试',
    link1Label: '链路 1 · 云主机 → ntfy',
    link2Label: '链路 2 · App 直连 USGS / tsunami.gov',
    e2eTest: '端到端推送测试',
    localTest: '本地通知测试',
    alertTest: '警报级测试（全屏 + 闹钟）',
    openSystemNotificationSettings: '打开系统通知设置',
    panelNote:
        '双链路：链路 1 走云主机 → ntfy；链路 2 由 App 直接轮询 USGS 与 tsunami.gov，'
        '云主机或 ntfy 挂掉时仍能收到。两条链路用事件 ID 去重。\n'
        '警报级（M7+ 地震、PAGER red、海啸 Warning/Threat）走 global_alert：全屏 + 闹钟音量 + 持续通知。\n'
        '澎湃 OS 4 适配：允许本应用「横幅通知」「锁屏通知」，省电策略设为「无限制」，并允许「自启动」。',
    tabQuakes: '地震（USGS）',
    tabTsunami: '海啸公报',
    listEmptyQuakes: '当前 24 小时内没有地震记录',
    listEmptyTsunami: '当前没有海啸公报',
    retry: '重试',
    close: '关闭',
    loadFailedUsgs: '拉取 USGS 失败',
    loadFailedTsunami: '拉取 tsunami.gov 失败',
    detailTime: '时间',
    detailPager: 'PAGER',
    detailTsunamiEval: '海啸评估',
    detailEventId: '事件 ID',
    valueYes: '是',
    valueNo: '否',
    valueNone: '无',
    timeUnknown: '时间未知',
    pushTileTitle: 'USGS / 海啸推送（ntfy）',
    pushTileSubtitleNtfy: '云主机轮询 USGS + tsunami.gov',
    sheetClose: '关闭',
    sheetServerLabel: '服务器',
    sheetTopicLabel: '主题',
    e2eOk: '已发布到 ntfy，订阅流收到后会自动弹通知。',
    e2eFail: '发布失败，检查网络或主题名。',
    localOk: '已弹出本地通知（不走网络）。',
    alertOk: '已弹出警报级通知（全屏 + 闹钟音量 + 持续）。',
  );

  static const en = AppStrings(
    appTitle: 'QuakePush',
    pushCardTitle: 'Earthquake / Tsunami push',
    bothLinksRunning: 'Both links online',
    bothLinksDown: 'Both links are down',
    linkNtfy: 'Server → ntfy',
    linkDirect: 'App direct feed',
    eventListTitle: 'Earthquakes / Tsunami',
    eventListSubtitle: 'USGS quakes (24h) + tsunami.gov bulletins',
    mapTitle: 'Global quake map',
    mapSubtitle: 'World basemap + epicentres coloured by magnitude',
    settingsTitle: 'Settings',
    settingsNotificationSection: 'Notifications',
    settingsNotificationTile: 'Notification settings',
    settingsNotificationSubtitle: 'Push channels and test notifications',
    settingsLanguage: 'Language',
    settingsAboutSection: 'About',
    settingsAboutBody:
        'EQMonitor v3.0.1 upstream + ntfy push integration. All UI and visual '
        'assets come from the upstream project.\n'
        'Data: USGS earthquake feed / tsunami.gov bulletins (PTWC / NTWC).\n'
        'Upstream: github.com/YumNumm/EQMonitor (MIT License).',
    settingsVersionTag: 'Multi-language build · ntfy push',
    notificationPageTitle: 'Notification settings',
    pushChannelSection: 'Push channels',
    systemSection: 'System',
    systemChannelTile: 'Android notification channels',
    systemChannelSubtitle: 'Banners, lock screen and sound behaviour of this app.',
    limitsSection: 'Limitations',
    limitsBody:
        'The app keeps the stream alive only while the process is running. After '
        'the system kills it, subscribe to the same topic in the ntfy client as a fallback.',
    panelTitle: 'USGS / Tsunami push test',
    link1Label: 'Link 1 · Server → ntfy',
    link2Label: 'Link 2 · App direct USGS / tsunami.gov',
    e2eTest: 'End-to-end push test',
    localTest: 'Local notification test',
    alertTest: 'Alert-level test (full screen + alarm)',
    openSystemNotificationSettings: 'Open system notification settings',
    panelNote:
        'Two links: link 1 is server → ntfy; link 2 polls USGS and tsunami.gov '
        'straight from the app, so it keeps working if the server or ntfy is down. '
        'Events are deduplicated by event id.\n'
        'Alert level (M7+ quakes, PAGER red, tsunami Warning/Threat) uses '
        'global_alert: full screen + alarm volume + ongoing notification.\n'
        'HyperOS 4: allow banner and lock-screen notifications, set battery saver '
        'to “No restrictions” and allow auto start.',
    tabQuakes: 'Quakes (USGS)',
    tabTsunami: 'Tsunami bulletins',
    listEmptyQuakes: 'No earthquakes in the last 24 hours',
    listEmptyTsunami: 'No tsunami bulletins right now',
    retry: 'Retry',
    close: 'Close',
    loadFailedUsgs: 'Failed to load USGS data',
    loadFailedTsunami: 'Failed to load tsunami.gov data',
    detailTime: 'Time',
    detailPager: 'PAGER',
    detailTsunamiEval: 'Tsunami evaluation',
    detailEventId: 'Event ID',
    valueYes: 'Yes',
    valueNo: 'No',
    valueNone: 'None',
    timeUnknown: 'Time unknown',
    pushTileTitle: 'USGS / Tsunami push (ntfy)',
    pushTileSubtitleNtfy: 'Server polls USGS + tsunami.gov',
    sheetClose: 'Close',
    sheetServerLabel: 'Server',
    sheetTopicLabel: 'Topic',
    e2eOk: 'Published to ntfy; the subscription shows a notification.',
    e2eFail: 'Publish failed. Check the network or topic name.',
    localOk: 'Local notification shown (no network).',
    alertOk: 'Alert-level notification shown (full screen + alarm + ongoing).',
  );

  static const ja = AppStrings(
    appTitle: 'QuakePush',
    pushCardTitle: '地震・津波プッシュ',
    bothLinksRunning: '2 経路とも稼働中',
    bothLinksDown: '2 経路とも切断',
    linkNtfy: 'サーバー → ntfy',
    linkDirect: 'アプリ直結ソース',
    eventListTitle: '地震・津波リスト',
    eventListSubtitle: '過去 24 時間の USGS 地震 + tsunami.gov 情報',
    mapTitle: '世界の地震マップ',
    mapSubtitle: '世界地図 + 震源ドット（マグニチュード別に色分け）',
    settingsTitle: '設定',
    settingsNotificationSection: '通知',
    settingsNotificationTile: '通知設定',
    settingsNotificationSubtitle: 'プッシュ経路・テスト通知',
    settingsLanguage: '表示言語',
    settingsAboutSection: 'このアプリについて',
    settingsAboutBody:
        'EQMonitor 本家（v3.0.1）+ ntfy プッシュ対応の改変版。UI と素材は上流プロジェクトのものです。\n'
        'データ: USGS 地震情報 / tsunami.gov 津波情報（PTWC / NTWC）。\n'
        '上流: github.com/YumNumm/EQMonitor (MIT License)。',
    settingsVersionTag: '多言語版 · ntfy プッシュ',
    notificationPageTitle: '通知設定',
    pushChannelSection: 'プッシュ経路',
    systemSection: 'システム',
    systemChannelTile: 'Android 通知チャンネル',
    systemChannelSubtitle: 'バナー・ロック画面表示・サウンドなど OS 側の通知動作を管理します。',
    limitsSection: '制限と補足',
    limitsBody:
        'アプリが動いている間は端末側で接続を維持します。OS に終了された場合は ntfy 公式クライアントで同じトピックを購読しておくと安心です。',
    panelTitle: 'USGS / 津波プッシュのテスト',
    link1Label: '経路 1 · サーバー → ntfy',
    link2Label: '経路 2 · アプリ直結 USGS / tsunami.gov',
    e2eTest: 'エンドツーエンド送信テスト',
    localTest: 'ローカル通知テスト',
    alertTest: 'アラート級テスト（全画面 + アラーム）',
    openSystemNotificationSettings: 'システムの通知設定を開く',
    panelNote:
        '2 経路あります。経路 1 はサーバー → ntfy、経路 2 はアプリが USGS と tsunami.gov を直接'
        'ポーリングするので、サーバーや ntfy が落ちても届きます。イベント ID で重複を除いています。\n'
        'アラート級（M7+・PAGER red・津波 Warning/Threat）は global_alert を使い、全画面 + アラーム音量 + 常駐通知になります。\n'
        'HyperOS 4 の場合: バナー通知とロック画面通知を許可し、バッテリー節約を「制限なし」、自動起動を許可してください。',
    tabQuakes: '地震（USGS）',
    tabTsunami: '津波情報',
    listEmptyQuakes: '過去 24 時間の地震はありません',
    listEmptyTsunami: '津波情報はありません',
    retry: '再試行',
    close: '閉じる',
    loadFailedUsgs: 'USGS の取得に失敗しました',
    loadFailedTsunami: 'tsunami.gov の取得に失敗しました',
    detailTime: '時刻',
    detailPager: 'PAGER',
    detailTsunamiEval: '津波評価',
    detailEventId: 'イベント ID',
    valueYes: 'はい',
    valueNo: 'いいえ',
    valueNone: 'なし',
    timeUnknown: '時刻不明',
    pushTileTitle: 'USGS / 津波プッシュ（ntfy）',
    pushTileSubtitleNtfy: 'サーバーが USGS + tsunami.gov を監視',
    sheetClose: '閉じる',
    sheetServerLabel: 'サーバー',
    sheetTopicLabel: 'トピック',
    e2eOk: 'ntfy に publish しました。購読側で通知が出るはずです。',
    e2eFail: 'publish に失敗しました。ネットワークとトピック名を確認してください。',
    localOk: 'ローカル通知を表示しました（ネットワークは使いません）。',
    alertOk: 'アラート級通知を表示しました（全画面 + アラーム + 常駐）。',
  );
}
