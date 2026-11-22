import 'package:app_settings/app_settings.dart';
import 'package:eqmonitor/core/component/progress/accessible_progress_indicator.dart';
import 'package:eqmonitor/core/component/sheet/app_sheet_route.dart';
import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/ntfy/ntfy_push_service.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

Future<void> openUsgsPushSheet(BuildContext context) async {
  await Navigator.of(context).push<void>(
    AppSheetRoute<void>(
      initialExtent: 0.55,
      builder: (_) => const _UsgsPushSheet(),
    ),
  );
}

class UsgsPushTile extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(ntfyPushStatusProvider).value ?? NtfyPushStatus.idle;
    final s = ref.watch(appStringsProvider);
    final isEn = ref.watch(appLocaleProvider).languageCode == 'en';
    return ListTile(
      title: Text(s.pushTileTitle),
      subtitle: Text(
        '${s.pushTileSubtitleNtfy} · ${isEn ? status.labelEn : status.label}',
      ),
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
    final isEnglish = ref.watch(appLocaleProvider).languageCode == 'en';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: isEnglish ? 'Close' : '关闭',
        ),
        title: Text(s.panelTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusRow(
            label: s.link1Label,
            value: isEnglish ? status.labelEn : status.label,
            ok: status == .connected,
          ),
          const SizedBox(height: 6),
          _StatusRow(
            label: s.link2Label,
            value: isEnglish ? direct.labelEn : direct.label,
            ok: direct == .ok,
          ),
          const SizedBox(height: 12),
          Text(
            '${isEnglish ? 'Server' : '服务器'} $ntfyServerUrl\n'
            '${isEnglish ? 'Topic' : '主题'} $ntfyTopic',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          M3EFilledButton(
            onPressed: pending.value != null
                ? null
                : () async {
                    pending.value = 'e2e';
                    final ok = await ref
                        .read(ntfyPushServiceProvider)
                        .sendEndToEndTest();
                    if (context.mounted) {
                      result.value = ok
                          ? (isEnglish
                                ? 'Published to ntfy; the subscription shows a notification.'
                                : '已发布到 ntfy，订阅流收到后会自动弹通知。')
                          : (isEnglish
                                ? 'Publish failed. Check the network or topic name.'
                                : '发布失败，检查网络或主题名。');
                      pending.value = null;
                    }
                  },
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
                : () async {
                    pending.value = 'local';
                    await ref.read(ntfyPushServiceProvider).showLocalTest();
                    if (context.mounted) {
                      result.value = isEnglish
                          ? 'Local notification shown (no network).'
                          : '已弹出本地通知（不走网络）。';
                      pending.value = null;
                    }
                  },
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
                : () async {
                    pending.value = 'alert';
                    await ref.read(ntfyPushServiceProvider).showAlertTest();
                    if (context.mounted) {
                      result.value = isEnglish
                          ? 'Alert-level notification shown (full screen + alarm + ongoing).'
                          : '已弹出警报级通知（全屏 + 闹钟音量 + 持续）。';
                      pending.value = null;
                    }
                  },
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
