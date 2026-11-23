import 'dart:convert';

import 'package:eqmonitor/feature/notification/data/model/push_history_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 推送历史的本地固化（沿用 PushFilterSetting 的做法：静态值 + 启动时 load）。
///
/// 列表最新在前，超出 [maxEntries] 时丢弃最旧的记录；整表以 JSON 字符串落盘，
/// 重启 App 后仍保留。
class PushHistorySetting {
  const PushHistorySetting._();

  static const prefsKey = 'push_history_v1';
  static const maxEntries = 200;

  static List<PushHistoryEntry> value = const [];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      value = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<Object?>;
      value = list
          .map((e) => PushHistoryEntry.fromJson(e as Map<String, Object?>))
          .toList();
    } on Object {
      value = const [];
    }
  }

  /// 追加一条记录；同 [PushHistoryEntry.id] 的旧记录先剔除，避免重复堆叠。
  static Future<void> add(PushHistoryEntry entry) async {
    final next = [
      entry,
      ...value.where((e) => e.id != entry.id),
    ].take(maxEntries).toList();
    value = List.unmodifiable(next);
    await _save();
  }

  static Future<void> clear() async {
    value = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      jsonEncode(value.map((e) => e.toJson()).toList()),
    );
  }
}
