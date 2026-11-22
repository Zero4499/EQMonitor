import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/ntfy/ntfy_push_service.dart';
import 'package:eqmonitor/core/router/router.dart';
import 'package:eqmonitor/feature/home/ui/component/sheet/component/home_sheet_card.dart';
import 'package:eqmonitor/feature/settings/features/notification_settings/ui/component/usgs_push_tile.dart';
import 'package:eqmonitor/page/event_list_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends HookConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorTheme = context.designSystem.colorTheme;

    return Scaffold(
      backgroundColor: colorTheme.surfaceContainerLow,
      appBar: AppBar(title: Text(ref.watch(appStringsProvider).appTitle)),
      body: const _SheetBody(),
    );
  }
}

class _SheetBody extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.designSystem.spacing;

    return ListView(
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.md, spacing.md, spacing.md),
      children: const [
        _PushStatusCard(),
        SizedBox(height: 12),
        _HomeActionsCard(),
      ],
    );
  }
}

class _PushStatusCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designSystem = context.designSystem;
    final colorTheme = designSystem.colorTheme;
    final spacing = designSystem.spacing;
    final typography = designSystem.typography;
    final s = ref.watch(appStringsProvider);
    final ntfyStatus =
        ref.watch(ntfyPushStatusProvider).value ?? NtfyPushStatus.idle;
    final directStatus =
        ref.watch(directFeedStatusProvider).value ?? DirectFeedStatus.idle;
    final ntfyConnected = ntfyStatus == NtfyPushStatus.connected;
    final directOk = directStatus == DirectFeedStatus.ok;
    final anyAlive = ntfyConnected || directOk;
    final isEnglish = ref.watch(appLocaleProvider).languageCode == 'en';

    return HomeSheetCard(
      children: [
        HomeSheetCardHeader(title: s.pushCardTitle),
        InkWell(
          onTap: () async => openUsgsPushSheet(context),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.sm,
              spacing.lg,
              spacing.md,
            ),
            child: Row(
              spacing: spacing.md,
              children: [
                Icon(
                  anyAlive ? Icons.podcasts : Icons.portable_wifi_off,
                  color: anyAlive ? Colors.teal : colorTheme.outline,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 4,
                    children: [
                      Text(
                        anyAlive ? s.bothLinksRunning : s.bothLinksDown,
                        style: typography.titleSmall,
                      ),
                      _LinkRow(
                        label: s.linkNtfy,
                        value: isEnglish
                            ? ntfyStatus.labelEn
                            : ntfyStatus.label,
                        ok: ntfyConnected,
                      ),
                      _LinkRow(
                        label: s.linkDirect,
                        value: isEnglish
                            ? directStatus.labelEn
                            : directStatus.label,
                        ok: directOk,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const new({required this.label, required this.value, required this.ok});

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final colorTheme = context.designSystem.colorTheme;
    final typography = context.designSystem.typography;
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.remove_circle_outline,
          size: 14,
          color: ok ? Colors.teal : colorTheme.outline,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label · $value',
            style: typography.bodySmall.copyWith(
              color: colorTheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeActionsCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.designSystem.spacing;
    final typography = context.designSystem.typography;
    final s = ref.watch(appStringsProvider);

    return HomeSheetCard(
      children: [
        Theme(
          data: Theme.of(context).copyWith(visualDensity: .compact),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              ListTile(
                title: Text(s.eventListTitle, style: typography.titleSmall),
                subtitle: Text(s.eventListSubtitle),
                leading: const Icon(Icons.list_alt),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const EventListPage(),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(s.settingsTitle, style: typography.titleSmall),
                leading: const Icon(Icons.settings_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async => const SettingsRoute().push<void>(context),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.xs),
      ],
    );
  }
}
