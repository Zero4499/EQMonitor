import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/ntfy/ntfy_push_service.dart';
import 'package:eqmonitor/core/router/router.dart';
import 'package:eqmonitor/feature/settings/features/notification_settings/ui/component/usgs_push_tile.dart';
import 'package:eqmonitor/page/event_list_page.dart';
import 'package:eqmonitor/page/quake_map.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// 首页：与 EQMonitor 一致——地图铺满屏幕，内容以可拖动面板浮在下方。
class HomePage extends HookConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final minMagnitude = useState<double>(0);

    return Scaffold(
      backgroundColor: context.designSystem.colorTheme.surfaceContainerLow,
      body: Stack(
        children: [
          Positioned.fill(child: QuakeMap(minMagnitude: minMagnitude.value)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: _HeaderBar(title: s.appTitle),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.44,
            minChildSize: 0.20,
            maxChildSize: 0.88,
            snap: true,
            snapSizes: const [0.44, 0.88],
            builder: (context, scrollController) => _HomeSheet(
              scrollController: scrollController,
              minMagnitude: minMagnitude.value,
              onMinMagnitudeChanged: (value) async => minMagnitude.value = value,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const new({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorTheme = context.designSystem.colorTheme;
    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colorTheme.surfaceContainerHigh.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _HomeSheet extends ConsumerWidget {
  const new({
    required this.scrollController,
    required this.minMagnitude,
    required this.onMinMagnitudeChanged,
  });

  final ScrollController scrollController;
  final double minMagnitude;
  final ValueChanged<double> onMinMagnitudeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorTheme = context.designSystem.colorTheme;
    final s = ref.watch(appStringsProvider);
    final isEnglish = ref.watch(appLocaleProvider).languageCode == 'en';
    final events = (ref.watch(usgsEventsProvider).value ?? const <UsgsEvent>[])
        .where((e) => e.hasLocation)
        .where((e) => (e.magnitude ?? 0) >= minMagnitude)
        .toList(growable: false);

    // 面板进入动画：淡入 + 轻微上移
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - t)),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorTheme.surface.withValues(alpha: 0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 18, spreadRadius: 2),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                children: [
                  _FilterRow(
                    minMagnitude: minMagnitude,
                    count: events.length,
                    isEnglish: isEnglish,
                    onChanged: onMinMagnitudeChanged,
                  ),
                  const SizedBox(height: 10),
                  const _PushStatusCard(),
                  const SizedBox(height: 10),
                  _TopEvents(eventList: events, isEnglish: isEnglish),
                  const SizedBox(height: 10),
                  _ActionsCard(isEnglish: isEnglish, s: s),
                  const SizedBox(height: 10),
                  _AllEvents(eventList: events, isEnglish: isEnglish),
                  const SizedBox(height: 8),
                  Text(
                    isEnglish
                        ? 'Basemap © OpenStreetMap / OpenFreeMap · events from USGS'
                        : '底图 © OpenStreetMap / OpenFreeMap · 事件来自 USGS',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const new({
    required this.minMagnitude,
    required this.count,
    required this.isEnglish,
    required this.onChanged,
  });

  final double minMagnitude;
  final int count;
  final bool isEnglish;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    const bands = <double>[0, 2.5, 4.5, 6];
    final labels = isEnglish
        ? <String>['All', 'M2.5+', 'M4.5+', 'M6+']
        : <String>['全部', 'M2.5+', 'M4.5+', 'M6+'];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < bands.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(labels[i]),
                      selected: minMagnitude == bands[i],
                      onSelected: (_) async => onChanged(bands[i]),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              isEnglish ? '$count' : '$count 条',
              key: ValueKey(count),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _PushStatusCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorTheme = context.designSystem.colorTheme;
    final spacing = context.designSystem.spacing;
    final s = ref.watch(appStringsProvider);
    final ntfyStatus =
        ref.watch(ntfyPushStatusProvider).value ?? NtfyPushStatus.idle;
    final directStatus =
        ref.watch(directFeedStatusProvider).value ?? DirectFeedStatus.idle;
    final ntfyConnected = ntfyStatus == NtfyPushStatus.connected;
    final directOk = directStatus == DirectFeedStatus.ok;
    final anyAlive = ntfyConnected || directOk;
    final isEnglish = ref.watch(appLocaleProvider).languageCode == 'en';

    return _Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async => openUsgsPushSheet(context),
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Row(
            spacing: spacing.md,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (anyAlive ? Colors.teal : colorTheme.outline)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  anyAlive ? Icons.podcasts : Icons.portable_wifi_off,
                  color: anyAlive ? Colors.teal : colorTheme.outline,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anyAlive ? s.bothLinksRunning : s.bothLinksDown,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    _LinkRow(
                      label: s.linkNtfy,
                      value: isEnglish ? ntfyStatus.labelEn : ntfyStatus.label,
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
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.remove_circle_outline,
          size: 13,
          color: ok ? Colors.teal : colorTheme.outline,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            '$label · $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorTheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopEvents extends StatelessWidget {
  const new({required this.eventList, required this.isEnglish});

  final List<UsgsEvent> eventList;
  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    final sorted = [...eventList]
      ..sort((a, b) => (b.magnitude ?? 0).compareTo(a.magnitude ?? 0));
    final top = sorted.take(3).toList(growable: false);

    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isEnglish ? 'Largest events' : '最强事件',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                _Legend(isEnglish: isEnglish),
              ],
            ),
            if (top.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  isEnglish ? 'No events above the filter.' : '当前筛选下没有事件。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            for (final event in top)
              InkWell(
                onTap: () async => _showEventDetail(
                  context,
                  event,
                  isEnglish: isEnglish,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: magnitudeColor(event.magnitude),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${event.magnitudeLabel}  ${event.place}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 最近事件列表（面板拉到最高时可滚动查看）。
class _AllEvents extends StatelessWidget {
  const new({required this.eventList, required this.isEnglish});

  final List<UsgsEvent> eventList;
  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    final colorTheme = context.designSystem.colorTheme;
    final shown = eventList.take(20).toList(growable: false);

    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEnglish ? 'Recent events' : '最近事件',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final event in shown)
              InkWell(
                onTap: () async => _showEventDetail(
                  context,
                  event,
                  isEnglish: isEnglish,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: magnitudeColor(event.magnitude),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: Text(
                          event.magnitudeLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          event.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${event.time.toLocal()}'
                            .split('.')
                            .first
                            .substring(11, 16),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const new({required this.isEnglish});

  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    const bands = <double>[1.5, 3.5, 5.5, 8];
    return Row(
      children: [
        for (final band in bands)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: magnitudeColor(band),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionsCard extends ConsumerWidget {
  const new({required this.isEnglish, required this.s});

  final bool isEnglish;
  final AppStrings s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = context.designSystem.typography;
    return _Card(
      child: Theme(
        data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(s.eventListTitle, style: typography.titleSmall),
              subtitle: Text(s.eventListSubtitle),
              leading: const Icon(Icons.list_alt),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const EventListPage()),
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
    );
  }
}

class _Card extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorTheme = context.designSystem.colorTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

Future<void> _showEventDetail(
  BuildContext context,
  UsgsEvent event, {
  required bool isEnglish,
}) async {
  final colorTheme = context.designSystem.colorTheme;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: magnitudeColor(event.magnitude),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  event.magnitudeLabel,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                if (event.tsunami == 1)
                  Chip(
                    label: Text(isEnglish ? 'Tsunami flag' : '海啸标记'),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                    backgroundColor: const Color(0xFFD62828),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(event.place, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '${event.time.toLocal()}'.split('.').first,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${isEnglish ? 'Coordinates' : '坐标'} '
              '${event.latitude!.toStringAsFixed(3)}, '
              '${event.longitude!.toStringAsFixed(3)} · '
              'PAGER ${event.pagerAlert ?? (isEnglish ? 'none' : '无')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: event.url.isEmpty
                        ? null
                        : () async => launchUrl(Uri.parse(event.url)),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(isEnglish ? 'Open in USGS' : '打开 USGS 详情'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async => Navigator.of(context).pop(),
                  child: Text(isEnglish ? 'Close' : '关闭'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
