import 'package:app_settings/app_settings.dart';
import 'package:eqmonitor/core/component/progress/accessible_progress_indicator.dart';
import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/component/sheet/app_sheet_route.dart';
import 'package:eqmonitor/core/ntfy/ntfy_push_service.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// 打开 USGS / 海啸推送测试面板。
Future<void> openUsgsPushSheet(BuildContext context) async {
  await Navigator.of(context).push<void>(
    AppSheetRoute<void>(
      initialExtent: 0.55,
      builder: (_) => const _UsgsPushSheet(),
    ),
  );
}

/// 「推送」栏的 USGS / 海啸推送入口。
class UsgsPushTile extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(ntfyPushStatusProvider).value ?? NtfyPushStatus.idle;
    final s = ref.watch(appStringsProvider);
    final isEn = ref.watch(appLocaleProvider).languageCode != 'zh';
    return ListTile(
      title: Text(s.pushTileTitle),
      subtitle: Text('${s.pushTileSubtitleNtfy} · ${isEn ? status.labelEn : status.label}'),
      leading: const Icon(Icons.public),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async => openUsgsPushSheet(context),
    );
  }
}

class _UsgsPushSheet extends HookConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(ntfyPushStatusProvider).value ?? NtfyPushStatus.idle;
    final s = ref.watch(appStringsProvider);
    final direct =
        ref.watch(directFeedStatusProvider).value ?? DirectFeedStatus.idle;
    final pending = useState<String?>(null);
    final result = useState<String?>(null);
    final language = ref.watch(appLocaleProvider).languageCode;

    /// 跑一次测试：无论成功、失败还是抛异常，都要把 pending 清掉，
    /// 否则按钮会永远停在"正在进行"的状态（之前就是这个毛病）。
    Future<void> run(String kind, Future<Object?> Function() action) async {
      pending.value = kind;
      String message;
      try {
        final value = await action();
        message = switch (kind) {
          'e2e' => value == true ? s.e2eOk : s.e2eFail,
          'local' => s.localOk,
          _ => s.alertOk,
        };
      } on Object {
        message = switch (kind) {
          'e2e' => s.e2eFail,
          'local' => s.localOk,
          _ => s.alertOk,
        };
      } finally {
        pending.value = null;
      }
      result.value = message;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: s.sheetClose,
        ),
        title: Text(s.panelTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusRow(
            label: s.link1Label,
            value: language == 'zh' ? status.label : status.labelEn,
            ok: status == .connected,
          ),
          const SizedBox(height: 6),
          _StatusRow(
            label: s.link2Label,
            value: language == 'zh' ? direct.label : direct.labelEn,
            ok: direct == .ok,
          ),
          const SizedBox(height: 12),
          Text(
            '${s.sheetServerLabel} $ntfyServerUrl\n'
            '${s.sheetTopicLabel} $ntfyTopic',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          M3EFilledButton(
            onPressed: pending.value != null
                ? null
                : () => run(
                    'e2e',
                    () => ref.read(ntfyPushServiceProvider).sendEndToEndTest(),
                  ),
            child: pending.value == 'e2e'
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: AccessibleCircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.e2eTest),
          ),
          const SizedBox(height: 8),
          M3EFilledButton.tonal(
            onPressed: pending.value != null
                ? null
                : () => run(
                    'local',
                    () => ref.read(ntfyPushServiceProvider).showLocalTest(),
                  ),
            child: pending.value == 'local'
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: AccessibleCircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.localTest),
          ),
          const SizedBox(height: 8),
          M3EFilledButton.tonal(
            onPressed: pending.value != null
                ? null
                : () => run(
                    'alert',
                    () => ref.read(ntfyPushServiceProvider).showAlertTest(),
                  ),
            child: pending.value == 'alert'
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: AccessibleCircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.alertTest),
          ),
          const SizedBox(height: 8),
          M3EFilledButton.tonal(
            onPressed: () async => AppSettings.openAppSettings(
              type: AppSettingsType.notification,
            ),
            child: Text(s.openSystemNotificationSettings),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(s.panelNote, style: Theme.of(context).textTheme.bodySmall),
          if (result.value case final message?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.designSystem.colorTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const new({required this.label, required this.value, required this.ok});

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final colorTheme = context.designSystem.colorTheme;
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.info_outline,
          size: 18,
          color: ok ? Colors.teal : colorTheme.outline,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorTheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
