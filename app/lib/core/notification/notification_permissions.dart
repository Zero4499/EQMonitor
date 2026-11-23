import 'dart:io';

import 'package:eqmonitor/core/fcm/channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 首次进入 App 时一次性申请「全部」通知相关权限：
///
/// 1. 通知权限（POST_NOTIFICATIONS，Android 13+）
/// 2. 全屏 intent 权限（USE_FULL_SCREEN_INTENT，Android 14+ 需显式授予）
/// 3. 勿扰/通知策略访问（Notification policy access）
/// 4. 电池优化白名单（避免国产 ROM 杀后台导致收不到推送）
///
/// 只在第一次进入时弹，之后可以在设置页里重新触发。
class NotificationPermissions {
  const NotificationPermissions._();

  static const prefsKey = 'notification_permission_prompt_v1';

  static const _channel = MethodChannel('sbs.ourstv.quakepush/permissions');

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      kIsWeb || !Platform.isAndroid
      ? null
      : FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

  /// 首次进入时调用；[force] 为 true 时无视「已处理过」的记录重新申请。
  static Future<void> requestAllIfNeeded({bool force = false}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(prefsKey) ?? false;
    if (alreadyAsked && !force) {
      return;
    }
    await requestNotifications();
    await requestFullScreenIntent();
    try {
      await _android?.requestNotificationPolicyAccess();
    } on Object {
      // 部分 ROM 不带这个入口，忽略
    }
    await requestIgnoreBatteryOptimizations();
    await prefs.setBool(prefsKey, true);
  }

  static Future<bool?> requestNotifications() async {
    try {
      return await _android?.requestNotificationsPermission();
    } on Object {
      return null;
    }
  }

  static Future<bool?> requestFullScreenIntent() async {
    try {
      return await _android?.requestFullScreenIntentPermission();
    } on Object {
      return null;
    }
  }

  /// 当前是否已获得「通知策略访问」（勿扰例外）权限。
  static Future<bool?> hasDndAccess() async {
    try {
      return await _android?.hasNotificationPolicyAccess();
    } on Object {
      return null;
    }
  }

  /// 申请「通知策略访问」：只有拿到这个权限，渠道的 bypassDnd 才会被系统认，
  /// 应用也才会出现在系统「勿扰模式 → 允许的应用」列表里。
  ///
  /// 拿到权限后需要把渠道删了重建一次：Android 不允许改已存在渠道的
  /// bypassDnd 字段，老渠道在没权限时被系统压成 false，重建后才会带上。
  static Future<bool?> requestDndAccess() async {
    final plugin = _android;
    if (plugin == null) {
      return null;
    }
    try {
      final already = await plugin.hasNotificationPolicyAccess();
      if (already == true) {
        await _recreateChannels();
        return true;
      }
      final granted = await plugin.requestNotificationPolicyAccess();
      if (granted == true) {
        await _recreateChannels();
      }
      return granted;
    } on Object {
      // 部分 ROM 没有这个入口，忽略
      return null;
    }
  }

  /// 删掉并重建本应用的全部通知渠道，让 bypassDnd 标记在拿到策略访问后重新生效。
  static Future<void> _recreateChannels() async {
    final plugin = _android;
    if (plugin == null) {
      return;
    }
    for (final channel in buildNotificationChannels()) {
      await plugin.deleteNotificationChannel(channelId: channel.id);
      await plugin.createNotificationChannel(channel);
    }
  }

  static Future<bool?> requestIgnoreBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
        'requestIgnoreBatteryOptimizations',
      );
    } on Object {
      return null;
    }
  }

  static Future<bool?> areNotificationsEnabled() async {
    try {
      return await _android?.areNotificationsEnabled();
    } on Object {
      return null;
    }
  }

  /// 打开本应用的通知渠道设置（澎湃 OS / HyperOS 上检查渠道是否被折叠）。
  static Future<void> openChannelSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } on Object {
      // ignore
    }
  }

  /// 打开本应用的系统详情页（权限 / 电池 / 通知汇总入口）。
  static Future<void> openAppDetailsSettings() async {
    try {
      await _channel.invokeMethod<void>('openAppDetailsSettings');
    } on Object {
      // ignore
    }
  }

  /// 跳后台自启动管理页；ROM 没有入口时原生侧退回应用详情页。
  static Future<void> openAutostartSettings() async {
    try {
      await _channel.invokeMethod<void>('openAutostartSettings');
    } on Object {
      // ignore
    }
  }

  /// 打开某一条具体通知渠道的系统设置页（声音 / 震动 / 灯色 / 重要性）。
  static Future<void> openChannelDetailSettings(String channelId) async {
    try {
      await _channel.invokeMethod<void>(
        'openChannelSettings',
        {'channelId': channelId},
      );
    } on Object {
      // ignore
    }
  }

  /// 焦点通知 / 超级岛协议版本：0 不支持，1 OS1，2 OS2 焦点，3 OS3 超级岛。
  static Future<int> focusProtocolVersion() async {
    try {
      return await _channel.invokeMethod<int>('focusProtocolVersion') ?? 0;
    } on Object {
      return 0;
    }
  }

  /// 本应用是否被允许显示焦点通知 / 超级岛。
  static Future<bool> hasFocusPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasFocusPermission') ?? false;
    } on Object {
      return false;
    }
  }

  /// 以原生链路发一条带超级岛参数的通知。
  ///
  /// 仅 OS3 且焦点权限已开通时原生侧才真正投递岛通知；否则返回 false，
  /// 调用方应回退到普通渠道通知。[accentColor] 为 `#RRGGBB` 强调色。
  static Future<bool> showIslandNotification({
    required String channelId,
    required String title,
    required String body,
    String? tag,
    bool alert = false,
    String? accentColor,
  }) async {
    try {
      return await _channel.invokeMethod<bool>(
            'showIslandNotification',
            {
              'channelId': channelId,
              'title': title,
              'body': body,
              'tag': tag,
              'alert': alert,
              'accentColor': accentColor,
            },
          ) ??
          false;
    } on Object {
      return false;
    }
  }

  /// 用原生 MediaPlayer 播一次分级提示音（res/raw 下的资源名，不带扩展名）。
  ///
  /// 国产 ROM（尤其 HyperOS）经常不给通知渠道里的 `android.resource://` 自定义
  /// 铃声出声，渠道设置页还会把它显示成「声音：无」。所以提示音改成由 App 自己播：
  /// 渠道只负责横幅 / 振动 / 呼吸灯，声音走这里，保证一定响。
  /// 应用通知被关闭、或该渠道被用户关掉时返回 false 且不播。
  static Future<bool> playAlertSound({
    required String sound,
    String? channelId,
    bool alert = false,
  }) async {
    try {
      return await _channel.invokeMethod<bool>(
            'playAlertSound',
            {'sound': sound, 'channelId': channelId, 'alert': alert},
          ) ??
          false;
    } on Object {
      return false;
    }
  }
}
