import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// QuakePush 只保留自己的通知渠道分组。
const notificationChannelGroups = <AndroidNotificationChannelGroup>[
  AndroidNotificationChannelGroup('earthquake', 'Earthquakes'),
  AndroidNotificationChannelGroup('tsunami', 'Tsunami'),
  AndroidNotificationChannelGroup('alert', 'Alert grade'),
];

/// QuakePush 自己的渠道：全球地震 / 海啸公报 / 警报级，外加一个兜底渠道
/// （上游 FCM 前台通知若未指定渠道时会落到它上面）。
const notificationChannels = <AndroidNotificationChannel>[
  AndroidNotificationChannel(
    'global_earthquake',
    'Earthquakes (USGS)',
    groupId: 'earthquake',
    description: 'Global earthquake alerts from the USGS feed',
    importance: Importance.high,
    showBadge: true,
  ),
  AndroidNotificationChannel(
    'global_tsunami',
    'Tsunami bulletins',
    groupId: 'tsunami',
    description: 'Tsunami bulletins and warnings from tsunami.gov',
    importance: Importance.high,
    showBadge: true,
  ),
  AndroidNotificationChannel(
    'global_alert',
    'Alert grade (M7+ / tsunami warning)',
    groupId: 'alert',
    description: 'M7+ earthquakes and tsunami warnings: full screen + alarm volume',
    importance: Importance.max,
    showBadge: true,
    playSound: true,
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  ),
  AndroidNotificationChannel(
    'service_fallback',
    'QuakePush fallback',
    description: 'Fallback channel when no channel id is supplied',
  ),
];

/// 启动时删除的渠道：上游 EQMonitor 的全部渠道 + 历史遗留 id。
///
/// 用户要求“把 EQ 的通知全删了，只留自己的”，因此这里把上游渠道逐个删掉，
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
];
