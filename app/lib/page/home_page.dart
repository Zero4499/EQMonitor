import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/i18n/tri.dart';
import 'package:eqmonitor/core/ntfy/ntfy_push_service.dart';
import 'package:eqmonitor/core/router/router.dart';
import 'package:eqmonitor/feature/settings/features/notification_settings/ui/component/usgs_push_tile.dart';
import 'package:eqmonitor/page/event_detail_sheet.dart';
import 'package:eqmonitor/page/event_list_page.dart';
import 'package:eqmonitor/page/quake_map.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 公报排序：警报 > 关注 > 信息 > 未知，同级按时间新到旧。
List<TsunamiBulletin> _sortedBulletins(List<TsunamiBulletin> input) {
  const weight = <TsunamiCategory, int>{
    TsunamiCategory.warning: 0,
    TsunamiCategory.advisory: 1,
    TsunamiCategory.info: 2,
    TsunamiCategory.unknown: 3,
  };
  final list = [...input]
    ..sort((a, b) {
      final w = weight[a.category]!.compareTo(weight[b.category]!);
      if (w != 0) return w;
      return (b.updated ?? DateTime(1970))
          .compareTo(a.updated ?? DateTime(1970));
    });
  return list;
}

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
          // 顶部标题胶囊（浮在地图上）
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
          // 可拖动内容面板
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
    final language = ref.watch(appLocaleProvider).languageCode;
    final events = (ref.watch(usgsEventsProvider).value ?? const <UsgsEvent>[])
        .where((e) => e.hasLocation)
        .where((e) => (e.magnitude ?? 0) >= minMagnitude)
        .toList(growable: false);
    final bulletins = _sortedBulletins(
      ref.watch(tsunamiBulletinsProvider).value ?? const <TsunamiBulletin>[],
    );
    final lastSyncedAt = ref.watch(feedLastSyncedAtProvider);

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
            // 拖动条
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
                    language: language,
                    onChanged: onMinMagnitudeChanged,
                  ),
                  if (bulletins.isNotEmpty)
                    _TsunamiBannerA(
                      bulletins: bulletins,
                      language: language,
                      s: s,
                    ),
                  const SizedBox(height: 10),
                  _PushStatusCard(),
                  const SizedBox(height: 10),
                  _TopEvents(eventList: events, language: language),
                  const SizedBox(height: 10),
                  _ActionsCard(language: language, s: s),
                  const SizedBox(height: 10),
                  _AllEvents(
                    eventList: events,
                    language: language,
                    lastSyncedAt: lastSyncedAt,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tri3(
                      language,
                      zh: '底图 © U.S. Geological Survey · The National Map · 事件来自 USGS',
                      en: 'Basemap © U.S. Geological Survey · The National Map · events from USGS',
                      ja: '地図 © U.S. Geological Survey · The National Map · 地震情報は USGS',
                    ),
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
    required this.language,
    required this.onChanged,
  });

  final double minMagnitude;
  final int count;
  final String language;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    const bands = <double>[0, 2.5, 4.5, 6];
    final labels = <String>[
      tri3(language, zh: '全部', en: 'All', ja: 'すべて'),
      'M2.5+',
      'M4.5+',
      'M6+',
    ];

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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            tri3(language, zh: '$count 条', en: '$count', ja: '$count 件'),
            key: ValueKey(count),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

/// 主推送状态卡：两条链路的实时状态，点击打开测试面板。
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
    final language = ref.watch(appLocaleProvider).languageCode;

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
                      value: ntfyStatus.displayLabel(language),
                      ok: ntfyConnected,
                    ),
                    _LinkRow(
                      label: s.linkDirect,
                      value: directStatus.displayLabel(language),
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

/// 方案 A：筛选行下方的全宽警示条，显示最严重的一条公报。
class _TsunamiBannerA extends StatelessWidget {
  const _TsunamiBannerA({
    required this.bulletins,
    required this.language,
    required this.s,
  });

  final List<TsunamiBulletin> bulletins;
  final String language;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final first = bulletins.first;
    final color = tsunamiCategoryColor(first.category);
    final more = bulletins.length > 1
        ? ' · ${s.bannerMoreCount.replaceAll('{n}', '${bulletins.length - 1}')}'
        : '';
    return _Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showTsunamiBulletinDetail(context, first, language: language),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            spacing: 12,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.waves, color: color),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tsunamiCategoryLabel(first.category, language),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      first.regionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '${_bulletinTime(first, language)}$more',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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

String _bulletinTime(TsunamiBulletin bulletin, String language) {
  final t = bulletin.updated;
  if (t == null) return tri3(language, zh: '时间未知', en: 'Time unknown', ja: '時刻不明');
  final two = (int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

class _TopEvents extends StatelessWidget {
  const new({required this.eventList, required this.language});

  final List<UsgsEvent> eventList;
  final String language;

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
                  tri3(
                    language,
                    zh: '最强事件',
                    en: 'Largest events',
                    ja: '最大の地震',
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                const _Legend(),
              ],
            ),
            if (top.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  tri3(
                    language,
                    zh: '当前筛选下没有事件。',
                    en: 'No events above the filter.',
                    ja: '条件に合う地震はありません。',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            for (final event in top)
              InkWell(
                onTap: () async => showUsgsEventDetail(
                  context,
                  event,
                  language: language,
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
  const new({
    required this.eventList,
    required this.language,
    this.lastSyncedAt,
  });

  final List<UsgsEvent> eventList;
  final String language;

  /// 最近一次成功从 USGS 拉取数据的时间；为空时说明还没拉过。
  final DateTime? lastSyncedAt;

  /// 12:05:30 —— 只显示时分秒，避免在主面板里占太多宽度。
  static String _clock(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    final colorTheme = context.designSystem.colorTheme;
    final shown = eventList.take(20).toList(growable: false);
    final syncedAt = lastSyncedAt;

    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  tri3(
                    language,
                    zh: '最近事件',
                    en: 'Recent events',
                    ja: '最近の地震',
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (syncedAt != null)
                  Text(
                    tri3(
                      language,
                      zh: '更新于 ${_clock(syncedAt)}',
                      en: 'Updated ${_clock(syncedAt)}',
                      ja: '更新 ${_clock(syncedAt)}',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorTheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final event in shown)
              InkWell(
                onTap: () async => showUsgsEventDetail(
                  context,
                  event,
                  language: language,
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
                        '${event.time.toLocal()}'.split('.').first.substring(11, 16),
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
  const new();

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
  const new({required this.language, required this.s});

  final String language;
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
