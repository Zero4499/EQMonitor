import 'package:eqmonitor/core/filter/push_history_setting.dart';
import 'package:eqmonitor/feature/notification/data/model/push_history_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 推送历史：内存态列表，写入同时落盘到 [PushHistorySetting]。
final pushHistoryProvider =
    NotifierProvider<PushHistoryNotifier, List<PushHistoryEntry>>(
      PushHistoryNotifier.new,
    );

class PushHistoryNotifier extends Notifier<List<PushHistoryEntry>> {
  @override
  List<PushHistoryEntry> build() => PushHistorySetting.value;

  Future<void> record(PushHistoryEntry entry) async {
    await PushHistorySetting.add(entry);
    state = List.unmodifiable(PushHistorySetting.value);
  }

  Future<void> clear() async {
    await PushHistorySetting.clear();
    state = const [];
  }
}
