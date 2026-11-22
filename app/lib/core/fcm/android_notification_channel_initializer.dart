import 'package:eqmonitor/core/fcm/channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 渠道 bypassDnd 迁移标记：老版本渠道是 false，需要删了重建才生效。
/// v2：补了 ACCESS_NOTIFICATION_POLICY 权限后再迁移一次，让渠道重建带上 bypassDnd。
const _bypassDndMigratedKey = 'notification_channel_bypass_dnd_v2';

abstract interface class AndroidNotificationChannelPlatform {
  Future<void> deleteChannel(String id);

  Future<void> createGroup(AndroidNotificationChannelGroup group);

  Future<void> createChannel(AndroidNotificationChannel channel);
}

class AndroidNotificationChannelInitializer {
  const new({required this.platform, this.isShakeDetectionEnabled = true});

  factory forCurrentPlatform({bool isShakeDetectionEnabled = true}) {
    if (kIsWeb) {
      return AndroidNotificationChannelInitializer(
        platform: const NoopAndroidNotificationChannelPlatform(),
        isShakeDetectionEnabled: isShakeDetectionEnabled,
      );
    }

    final targetPlatform = defaultTargetPlatform;
    final androidPlugin = targetPlatform == TargetPlatform.android
        ? FlutterLocalNotificationsPlugin()
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
        : null;
    return AndroidNotificationChannelInitializer.forPlatform(
      targetPlatform: targetPlatform,
      androidPlugin: androidPlugin,
      isShakeDetectionEnabled: isShakeDetectionEnabled,
    );
  }

  factory forPlatform({
    required TargetPlatform targetPlatform,
    required AndroidFlutterLocalNotificationsPlugin? androidPlugin,
    bool isShakeDetectionEnabled = true,
  }) {
    if (targetPlatform != TargetPlatform.android) {
      return AndroidNotificationChannelInitializer(
        platform: const NoopAndroidNotificationChannelPlatform(),
        isShakeDetectionEnabled: isShakeDetectionEnabled,
      );
    }
    if (androidPlugin == null) {
      throw StateError(
        'AndroidFlutterLocalNotificationsPlugin is unavailable on Android',
      );
    }
    return AndroidNotificationChannelInitializer(
      platform: AndroidFlutterLocalNotificationsChannelPlatform(
        plugin: androidPlugin,
      ),
      isShakeDetectionEnabled: isShakeDetectionEnabled,
    );
  }

  final AndroidNotificationChannelPlatform platform;
  final bool isShakeDetectionEnabled;

  Future<void> initialize() async {
    final activeChannels = notificationChannels.where(
      (channel) => isShakeDetectionEnabled || channel.id != 'shake_detection',
    );
    final activeChannelIds = activeChannels
        .map((channel) => channel.id)
        .toSet();
    if (!isShakeDetectionEnabled) {
      await platform.deleteChannel('shake_detection');
    }
    for (final id in legacyNotificationChannelIds) {
      if (activeChannelIds.contains(id)) {
        continue;
      }
      await platform.deleteChannel(id);
    }
    // 早期版本的渠道是 bypassDnd=false（勿扰模式下不响），而 Android 不允许
    // 修改已存在渠道的这个字段，只能删了重建，所以这里做一次性迁移。
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_bypassDndMigratedKey) ?? false)) {
      for (final id in activeChannelIds) {
        await platform.deleteChannel(id);
      }
      await prefs.setBool(_bypassDndMigratedKey, true);
    }
    for (final group in notificationChannelGroups) {
      await platform.createGroup(group);
    }
    for (final channel in activeChannels) {
      await platform.createChannel(channel);
    }
  }
}

class const AndroidFlutterLocalNotificationsChannelPlatform({
  required final AndroidFlutterLocalNotificationsPlugin plugin,
}) implements AndroidNotificationChannelPlatform {
  @override
  Future<void> deleteChannel(String id) =>
      plugin.deleteNotificationChannel(channelId: id);

  @override
  Future<void> createGroup(AndroidNotificationChannelGroup group) =>
      plugin.createNotificationChannelGroup(group);

  @override
  Future<void> createChannel(AndroidNotificationChannel channel) =>
      plugin.createNotificationChannel(channel);
}

class const NoopAndroidNotificationChannelPlatform()
    implements AndroidNotificationChannelPlatform {
  @override
  Future<void> deleteChannel(String id) async {}

  @override
  Future<void> createGroup(AndroidNotificationChannelGroup group) async {}

  @override
  Future<void> createChannel(AndroidNotificationChannel channel) async {}
}
