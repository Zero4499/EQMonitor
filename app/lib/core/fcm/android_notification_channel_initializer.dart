import 'package:eqmonitor/core/fcm/channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 渠道 bypassDnd 迁移标记：老版本渠道是 false，需要删了重建才生效。
/// v2：补了 ACCESS_NOTIFICATION_POLICY 权限后再迁移一次，让渠道重建带上 bypassDnd。
const _bypassDndMigratedKey = 'notification_channel_bypass_dnd_v2';

/// 提示音迁移标记：渠道声音在 Android 上一旦创建不会被后续重建覆盖，
/// 接入分级提示音后需要把旧渠道删一次，按新声音重建。
/// v3：再重建一次，让分级呼吸灯颜色与振动节奏落到老渠道上。
///
/// 注意：Android 对「删掉再用同一个 id 重建」会保留旧配置，所以 4006 起渠道 id
/// 整体换成 `*_v3` 新 id（从未创建过的 id 才能真正带上新参数）。
const _soundMigratedKey = 'notification_channel_sound_v3';

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
    final activeChannels = buildNotificationChannels().where(
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
    // 分级提示音迁移：旧渠道的声音不会被覆盖，需要删一次再按新声音重建。
    if (!(prefs.getBool(_soundMigratedKey) ?? false)) {
      for (final id in activeChannelIds) {
        await platform.deleteChannel(id);
      }
      await prefs.setBool(_soundMigratedKey, true);
    }
    // 无声渠道迁移：声音改由 App 自播，旧渠道残留的声音必须清掉，否则会双响。
    // 4006 起渠道 id 整体换成 `*_v3`，旧 id 已在 legacyNotificationChannelIds 里删除，
    // 新 id 是从未创建过的，所以这里不需要再删一遍。
    for (final group in buildNotificationChannelGroups()) {
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
