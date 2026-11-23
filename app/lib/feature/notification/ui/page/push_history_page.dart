import 'package:eqmonitor/core/component/widget/app_empty_state.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/i18n/tri.dart';
import 'package:eqmonitor/core/provider/notification/push_history_provider.dart';
import 'package:eqmonitor/feature/notification/data/model/push_history_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// 推送历史：本机已下发过的通知记录，本地固化、重启不丢。
class PushHistoryPage extends ConsumerWidget {
  const PushHistoryPage({super.key});

  String _formatTime(int epochMs) {
    final t = DateTime.fromMillisecondsSinceEpoch(epochMs);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(pushHistoryProvider);
    final lang = ref.watch(appLocaleProvider).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tri3(lang, zh: '推送历史', en: 'Push history', ja: 'プッシュ履歴'),
        ),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: tri3(lang, zh: '清空历史', en: 'Clear history', ja: '履歴を消去'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmClear(context, ref, lang),
            ),
        ],
      ),
      body: history.isEmpty
          ? AppEmptyState(
              icon: Icons.notifications_none_outlined,
              message: tri3(
                lang,
                zh: '暂无推送记录',
                en: 'No push history yet',
                ja: 'プッシュ履歴はありません',
              ),
              description: tri3(
                lang,
                zh: '收到的地震 / 海啸通知会保留在这里',
                en: 'Earthquake and tsunami alerts you receive will show up here',
                ja: '受信した地震・津波通知がここに残ります',
              ),
            )
          : ListView.separated(
              itemCount: history.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _HistoryTile(entry: history[index], lang: lang, formatTime: _formatTime),
            ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    String lang,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tri3(lang, zh: '清空推送历史？', en: 'Clear push history?', ja: '履歴を消去しますか？'),
        ),
        content: Text(
          tri3(
            lang,
            zh: '本地保存的全部推送记录将被删除，此操作不可撤销。',
            en: 'All locally stored push records will be deleted. This cannot be undone.',
            ja: 'ローカルに保存されたすべての履歴を削除します。この操作は元に戻せません。',
          ),
        ),
        actions: [
          M3ETextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tri3(lang, zh: '取消', en: 'Cancel', ja: 'キャンセル')),
          ),
          M3EFilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tri3(lang, zh: '清空', en: 'Clear', ja: '消去')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(pushHistoryProvider.notifier).clear();
    }
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.lang,
    required this.formatTime,
  });

  final PushHistoryEntry entry;
  final String lang;
  final String Function(int epochMs) formatTime;

  IconData get _icon => switch (entry.kind) {
    PushHistoryKind.quake => Icons.circle,
    PushHistoryKind.tsunami => Icons.waves,
    PushHistoryKind.test => Icons.science_outlined,
    PushHistoryKind.other => Icons.info_outline,
  };

  Color _iconColor(BuildContext context) => switch (entry.kind) {
    PushHistoryKind.tsunami => const Color(0xFF2FA8E1),
    PushHistoryKind.quake =>
      entry.alert ? const Color(0xFFD62828) : Theme.of(context).colorScheme.onSurfaceVariant,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };

  String get _sourceLabel => switch (entry.source) {
    PushHistorySource.direct => tri3(lang, zh: '直连', en: 'Direct', ja: '直接'),
    PushHistorySource.ntfy => 'ntfy',
    PushHistorySource.fcm => 'FCM',
    PushHistorySource.other => '',
  };

  @override
  Widget build(BuildContext context) {
    final url = entry.url;
    final hasUrl = url != null && url.isNotEmpty;
    final subtitle = [
      if (entry.body.isNotEmpty) entry.body,
      [formatTime(entry.timestamp), _sourceLabel]
          .where((s) => s.isNotEmpty)
          .join(' · '),
    ].where((s) => s.isNotEmpty).join('\n');

    return ListTile(
      leading: Icon(_icon, color: _iconColor(context)),
      title: Text(
        entry.title,
        style: entry.alert
            ? const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD62828))
            : null,
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 3),
      trailing: hasUrl ? const Icon(Icons.chevron_right) : null,
      onTap: hasUrl
          ? () {
              final u = entry.url;
              if (u != null && u.isNotEmpty) {
                launchUrlString(u, mode: LaunchMode.externalApplication);
              }
            }
          : null,
    );
  }
}
