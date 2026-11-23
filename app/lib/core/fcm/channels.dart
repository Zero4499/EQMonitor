import 'dart:typed_data';

import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/i18n/tri.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 当前界面语言（通知渠道在后台注册时拿不到 BuildContext，读静态设置）。
String get _channelLanguage => AppLocaleSetting.value.languageCode;

/// 提示音（res/raw 下的 MP3，资源名不带扩展名）。
/// 036 默认通知音 / 066 M7 地震 / 065 海啸 / 067 M8 地震。
///
/// 注意：这些声音**不再**写进系统通知渠道。国产 ROM（尤其 HyperOS）对渠道里的
/// `android.resource://` 自定义铃声经常不播，渠道设置页还会显示成「声音：无」。
/// 现在渠道只负责横幅 / 振动 / 呼吸灯，声音由 App 用原生 MediaPlayer 播
/// （见 [alertSoundForChannel] 与 NotificationPermissions.playAlertSound）。
const soundDefaultRes = 'notif_default';
const soundQuakeM7Res = 'quake_m7';
const soundTsunamiRes = 'tsunami';
const soundQuakeM8Res = 'quake_m8';

/// 渠道 → 提示音资源名。警报级沿用 M8 音，保证「最急」的听起来一样。
const _soundByChannelId = <String, String>{
  'global_earthquake_v3': soundDefaultRes,
  'global_earthquake_m7_v3': soundQuakeM7Res,
  'global_earthquake_m8_v3': soundQuakeM8Res,
  'global_tsunami_v3': soundTsunamiRes,
  'global_alert_v3': soundQuakeM8Res,
  'service_fallback_v3': soundDefaultRes,
};

/// 取某条渠道该播的提示音资源名；未知渠道回落到默认音。
String alertSoundForChannel(String channelId) =>
    _soundByChannelId[channelId] ?? soundDefaultRes;


/// 分级呼吸灯颜色：普通蓝、M7 橙、M8/警报红、海啸蓝。
const _ledDefault = Color(0xFF2FA8E1);
const _ledM7 = Color(0xFFF5A623);
const _ledM8 = Color(0xFFD62828);
const _ledTsunami = Color(0xFF2FA8E1);
const _ledAlert = Color(0xFFD62828);

/// 分级振动节奏（毫秒：等待, 开, 关, 开 ...）。
final _vibDefault = Int64List.fromList(const [0, 120]);
final _vibM7 = Int64List.fromList(const [0, 180, 120, 180]);
final _vibM8 = Int64List.fromList(const [0, 300, 120, 300, 120, 400]);
final _vibTsunami = Int64List.fromList(const [0, 220, 100, 220]);

/// QuakePush 只保留自己的通知渠道分组。名称/描述跟随 App 语言。
List<AndroidNotificationChannelGroup> buildNotificationChannelGroups() => [
  AndroidNotificationChannelGroup(
    'earthquake',
    tri3(_channelLanguage, zh: '地震', en: 'Earthquakes', ja: '地震'),
  ),
  AndroidNotificationChannelGroup(
    'tsunami',
    tri3(_channelLanguage, zh: '海啸', en: 'Tsunami', ja: '津波'),
  ),
  AndroidNotificationChannelGroup(
    'alert',
    tri3(_channelLanguage, zh: '警报级', en: 'Alert grade', ja: 'アラート級'),
  ),
];

/// QuakePush 自己的渠道：按震级 / 类型分渠道，各自独立的振动节奏与呼吸灯颜色。
/// 声音不放进渠道（见文件顶部说明），由 App 侧原生播放；渠道只管横幅 / 振动 / 灯色。
/// 名称/描述跟随 App 语言。
List<AndroidNotificationChannel> buildNotificationChannels() => [
  AndroidNotificationChannel(
    'global_earthquake_v3',
    tri3(
      _channelLanguage,
      zh: '地震（USGS）',
      en: 'Earthquakes (USGS)',
      ja: '地震（USGS）',
    ),
    groupId: 'earthquake',
    description: tri3(
      _channelLanguage,
      zh: 'M7 以下的全球地震提醒',
      en: 'Global earthquakes below M7 from the USGS feed',
      ja: 'M7 未満の全球地震情報',
    ),
    importance: Importance.high,
    showBadge: true,
    playSound: false,
    enableLights: true,
    ledColor: _ledDefault,
    enableVibration: true,
    vibrationPattern: _vibDefault,
    // 勿扰模式下也允许响：需要在系统里给本应用「通知策略访问」权限，
    // 否则这个标记会被系统当成 false（见 NotificationPermissions）。
    bypassDnd: true,
  ),
  AndroidNotificationChannel(
    'global_earthquake_m7_v3',
    tri3(
      _channelLanguage,
      zh: '地震 M7.0–7.9',
      en: 'Earthquake M7.0–7.9',
      ja: '地震 M7.0–7.9',
    ),
    groupId: 'earthquake',
    description: tri3(
      _channelLanguage,
      zh: 'M7.0–7.9 地震：强提醒 + 专用提示音',
      en: 'M7.0–7.9 earthquakes: prominent alert with dedicated tone',
      ja: 'M7.0–7.9 地震：強めの通知と専用サウンド',
    ),
    importance: Importance.high,
    showBadge: true,
    playSound: false,
    enableLights: true,
    ledColor: _ledM7,
    enableVibration: true,
    vibrationPattern: _vibM7,
    bypassDnd: true,
  ),
  AndroidNotificationChannel(
    'global_earthquake_m8_v3',
    tri3(
      _channelLanguage,
      zh: '地震 M8.0+',
      en: 'Earthquake M8.0+',
      ja: '地震 M8.0+',
    ),
    groupId: 'earthquake',
    description: tri3(
      _channelLanguage,
      zh: 'M8.0+ 地震：全屏弹出 + 闹钟音量 + 专用提示音',
      en: 'M8.0+ earthquakes: full screen + alarm volume + dedicated tone',
      ja: 'M8.0+ 地震：全画面 + アラーム音量 + 専用サウンド',
    ),
    importance: Importance.max,
    showBadge: true,
    playSound: false,
    enableLights: true,
    ledColor: _ledM8,
    enableVibration: true,
    vibrationPattern: _vibM8,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    bypassDnd: true,
  ),
  AndroidNotificationChannel(
    'global_tsunami_v3',
    tri3(
      _channelLanguage,
      zh: '海啸公报',
      en: 'Tsunami bulletins',
      ja: '津波情報',
    ),
    groupId: 'tsunami',
    description: tri3(
      _channelLanguage,
      zh: '来自 tsunami.gov 的海啸公报与警报',
      en: 'Tsunami bulletins and warnings from tsunami.gov',
      ja: 'tsunami.gov からの津波情報・警報',
    ),
    importance: Importance.high,
    showBadge: true,
    playSound: false,
    enableLights: true,
    ledColor: _ledTsunami,
    enableVibration: true,
    vibrationPattern: _vibTsunami,
    bypassDnd: true,
  ),
  AndroidNotificationChannel(
    'global_alert_v3',
    tri3(
      _channelLanguage,
      zh: '警报级（M7+ / 海啸警报）',
      en: 'Alert grade (M7+ / tsunami warning)',
      ja: 'アラート級（M7+ / 津波警報）',
    ),
    groupId: 'alert',
    description: tri3(
      _channelLanguage,
      zh: 'M7+ 地震与海啸警报：全屏弹出 + 闹钟音量',
      en: 'M7+ earthquakes and tsunami warnings: full screen + alarm volume',
      ja: 'M7+ 地震・津波警報：全画面 + アラーム音量',
    ),
    importance: Importance.max,
    showBadge: true,
    playSound: false,
    enableLights: true,
    ledColor: _ledAlert,
    enableVibration: true,
    vibrationPattern: _vibM8,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    bypassDnd: true,
  ),
  AndroidNotificationChannel(
    'service_fallback_v3',
    tri3(
      _channelLanguage,
      zh: 'QuakePush 兜底渠道',
      en: 'QuakePush fallback',
      ja: 'QuakePush フォールバック',
    ),
    description: tri3(
      _channelLanguage,
      zh: '未指定渠道时使用的兜底渠道',
      en: 'Fallback channel when no channel id is supplied',
      ja: 'チャンネル未指定時のフォールバック',
    ),
    playSound: false,
    bypassDnd: true,
  ),
];

/// 启动时删除的渠道：上游 EQMonitor 的全部渠道 + 历史遗留 id。
///
/// 用户要求「把 EQ 的通知全删了，只留自己的」，因此这里把上游渠道逐个删掉，
/// 已经装过旧版本的用户升级后也不会再看到 `EEW` / `津波` 之类的渠道。
const legacyNotificationChannelIds = <String>[
  // 旧版历史 id
  'fromdev',
  'bgl_debug',
  'eew_warning',
  'eew_forecast',
  'eew_low_accuracy',
  'VXSE51',
  'VXSE52',
  'VXSE53',
  'VXSE61',
  'VXSE62',
  'VZSE40',
  'VYSE50',
  'VYSE51',
  'VYSE52',
  'test',
  'test_critical',
  // 上游 EQMonitor v3.0.1 的渠道
  'eew_warning_current_location',
  'eew_warning_nationwide',
  'eew_forecast',
  'eew_low_accuracy_v2',
  'earthquake_vxse51',
  'earthquake_vxse52',
  'earthquake_vxse53',
  'earthquake_vxse61',
  'earthquake_vxse62',
  'earthquake_estimated_intensity',
  'tsunami_major_warning',
  'tsunami_warning',
  'tsunami_advisory',
  'tsunami_update',
  'tsunami_passive',
  'earthquake_notice',
  'nankai_information',
  'aftershock_advisory',
  'shake_detection',
  'training_information',
  'service_test',
  'service_test_critical',
  // 本项目旧版渠道：接入分级提示音后改用 v2 渠道 id（旧渠道声音不可变更，需删除）。
  'global_earthquake',
  'global_tsunami',
  'global_alert',
  'service_fallback',
  // 4006：提示音改由 App 自播，渠道换成无声的 `*_v3` id，旧的 v2 渠道一并删掉。
  'global_earthquake_v2',
  'global_earthquake_m7',
  'global_earthquake_m8',
  'global_tsunami_v2',
  'global_alert_v2',
  'service_fallback_v2',
];
