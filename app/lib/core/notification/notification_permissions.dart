import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 首次进入 App 时一次性申请「全部」通知相关权限：
///
/// 1. 通知权限（POST_NOTIFICATIONS，Android 13+）
/// 2. 全屏 intent 权限（USE_FULL_SCREEN_INTENT，Android 14+ 需显式授予）
/// 3. 精确闹钟权限（SCHEDULE_EXACT_ALARM）
/// 4. 勿扰/通知策略访问（Notification policy access）
/// 5. 电池优化白名单（避免国产 ROM 杀后台导致收不到推送）
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
    await requestExactAlarms();
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

  static Future<bool?> requestExactAlarms() async {
    try {
      return await _android?.requestExactAlarmsPermission();
    } on Object {
      return null;
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
}
