import 'dart:async';

import 'package:collection/collection.dart';
import 'package:eqmonitor/core/fcm/android_notification_channel_initializer.dart';
import 'package:eqmonitor/core/fcm/channels.dart';
import 'package:eqmonitor/core/fcm/foreground_notification_payload_codec.dart';
import 'package:eqmonitor/core/notification/notification_permissions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationRepository {
  new({
    required this.plugin,
    required this.channelInitializer,
    required this.isAndroid,
    required Stream<RemoteMessage> foregroundMessages,
  }) : _foregroundMessages = foregroundMessages;

  factory forCurrentPlatform({bool isShakeDetectionEnabled = true}) =>
      LocalNotificationRepository(
        plugin: FlutterLocalNotificationsPlugin(),
        channelInitializer:
            AndroidNotificationChannelInitializer.forCurrentPlatform(
              isShakeDetectionEnabled: isShakeDetectionEnabled,
            ),
        isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
        foregroundMessages: FirebaseMessaging.onMessage,
      );

  final FlutterLocalNotificationsPlugin plugin;
  final AndroidNotificationChannelInitializer channelInitializer;
  final bool isAndroid;
  final Stream<RemoteMessage> _foregroundMessages;
  final _openedMessages = StreamController<RemoteMessage>.broadcast();
  Future<void>? _initialization;
  var _nextNotificationId = 0;

  Stream<RemoteMessage> get foregroundMessages =>
      isAndroid ? _foregroundMessages : const Stream.empty();

  Stream<RemoteMessage> get openedMessages => _openedMessages.stream;

  Future<void> initialize() => _initialization ??= initializePlatform();

  Future<void> initializePlatform() async {
    await channelInitializer.initialize();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: handleResponse,
    );
  }

  /// 切换界面语言后，按新语言重建渠道名 / 分组名。
  /// （importance、bypassDnd 等不可变字段不受影响；这里只是重新注册同名渠道刷新文案。）
  Future<void> refreshLocalizedChannels() async {
    if (!isAndroid) return;
    await channelInitializer.initialize();
  }

  Future<RemoteMessage?> getInitialMessage() async {
    if (!isAndroid) {
      return null;
    }
    await initialize();
    final details = await plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? const ForegroundNotificationPayloadCodec().decode(
            details?.notificationResponse?.payload,
          )
        : null;
  }

  void handleResponse(NotificationResponse response) {
    final message = const ForegroundNotificationPayloadCodec().decode(
      response.payload,
    );
    if (message != null && !_openedMessages.isClosed) {
      _openedMessages.add(message);
    }
  }

  Future<void> showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (!isAndroid || notification == null) {
      return;
    }
    if (!channelInitializer.isShakeDetectionEnabled &&
        notification.android?.channelId == 'shake_detection') {
      return;
    }
    await initialize();
    final android = notification.android;
    final channel = await resolveChannel(android?.channelId);
    final tag = android?.tag;
    final identity = tag != null && tag.isNotEmpty ? tag : message.messageId;
    await plugin.show(
      id: (identity?.hashCode ?? _nextNotificationId++) & 0x7fffffff,
      title: notification.title,
      body: notification.body,
      payload: const ForegroundNotificationPayloadCodec().encode(message),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: switch (channel.importance) {
            Importance.max || Importance.high => Priority.high,
            Importance.low => Priority.low,
            Importance.min || Importance.none => Priority.min,
            _ => Priority.defaultPriority,
          },
          playSound: false,
          enableVibration: channel.enableVibration,
          vibrationPattern: channel.vibrationPattern,
          icon: 'ic_notification_icon',
          tag: tag,
          styleInformation: BigTextStyleInformation(notification.body ?? ''),
        ),
      ),
    );
    await _playChannelSound(channel.id);
  }

  /// 渠道本身不出声，提示音由 App 自己播（HyperOS 上渠道自定义铃声不生效）。
  Future<void> _playChannelSound(String channelId) async {
    final isAlarmGrade =
        channelId == 'global_earthquake_m8_v3' || channelId == 'global_alert_v3';
    final sound = alertSoundForChannel(channelId);
    final played = await NotificationPermissions.playAlertSound(
      sound: sound,
      channelId: channelId,
      alert: isAlarmGrade,
    );
    debugPrint('QuakePushSound dart: channel=$channelId sound=$sound played=$played');
  }

  /// FCM を経由しない通知（USGS / tsunami.gov の ntfy プッシュなど）を表示する。
  ///
  /// [alert] 为 true 时按警报级处理：全屏弹出 + 闹钟音量 + 强震动，用于
  /// M7+ 地震 / 海啸 Warning・Threat。
  Future<void> showSimpleNotification({
    required String title,
    required String body,
    String? channelId,
    String? tag,
    bool alert = false,
  }) async {
    if (!isAndroid) {
      return;
    }
    await initialize();
    // 显式指定渠道（按震级 / 类型分音）优先；只有未指定渠道的警报级通知才落到 global_alert。
    final channel = await resolveChannel(channelId ?? (alert ? 'global_alert_v3' : null));
    // 警报级通知优先尝试超级岛投递；原生侧判断非 OS3 / 无焦点权限 / 异常时返回 false，
    // 随即回退到下面的普通渠道通知，保证告警送达不被岛能力阻塞。
    if (alert) {
      final accent = switch (channel.id) {
        'global_earthquake_m8_v3' || 'global_alert_v3' => '#D62828',
        'global_earthquake_m7_v3' => '#F5A623',
        'global_tsunami_v3' => '#2FA8E1',
        _ => '#2FA8E1',
      };
      final islandSent = await NotificationPermissions.showIslandNotification(
        channelId: channel.id,
        title: title,
        body: body,
        tag: tag,
        alert: true,
        accentColor: accent,
      );
      if (islandSent) {
        await _playChannelSound(channel.id);
        return;
      }
    }
    final identity = tag != null && tag.isNotEmpty ? tag : '$title-$body';
    await plugin.show(
      id: identity.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: alert
              ? Priority.max
              : switch (channel.importance) {
                  Importance.max || Importance.high => Priority.high,
                  Importance.low => Priority.low,
                  Importance.min || Importance.none => Priority.min,
                  _ => Priority.defaultPriority,
                },
          playSound: false,
          enableVibration: channel.enableVibration,
          vibrationPattern: channel.vibrationPattern,
          icon: 'ic_notification_icon',
          tag: tag,
          fullScreenIntent: alert,
          category: alert
              ? AndroidNotificationCategory.alarm
              : AndroidNotificationCategory.status,
          audioAttributesUsage: alert
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          // 澎湃 OS / HyperOS 适配：渠道角标 + 呼吸灯 + 非静默，避免被折叠成低优先级
          channelShowBadge: true,
          enableLights: true,
          onlyAlertOnce: false,
          ticker: title,
          // 警报级设为持续通知，锁屏上也保持可见，直到用户点开
          ongoing: alert,
          autoCancel: !alert,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
    await _playChannelSound(channel.id);
  }

  Future<AndroidNotificationChannel> resolveChannel(String? requestedId) async {
    final migratedId = switch (requestedId) {
      'test' => 'service_test',
      'test_critical' => 'service_test_critical',
      _ => requestedId,
    };
    final id = migratedId == null || migratedId.isEmpty
        ? 'service_fallback_v3'
        : migratedId;
    final registered = buildNotificationChannels().firstWhereOrNull((c) => c.id == id);
    if (registered != null) {
      return registered;
    }
    final existing = await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.getNotificationChannels();
    final channel = existing?.firstWhereOrNull((c) => c.id == id);
    // FCM と同じく、指定 channel が OS に存在しなければ Manifest の既定値を使う。
    return channel ??
        buildNotificationChannels().firstWhere((c) => c.id == 'service_fallback_v3');
  }

  Future<void> dispose() => _openedMessages.close();
}
