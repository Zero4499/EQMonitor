import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/page/event_detail_sheet.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 震级配色（借鉴各地震 App 的惯例：小震低调，大震醒目）。
/// 分档按 1 级一个台阶，这样地球上每天都在发生的 M1~M3 也能看出层次。
Color magnitudeColor(double? magnitude) {
  final mag = magnitude ?? 0;
  if (mag < 1.5) {
    return const Color(0xFF8FA3B8); // 灰蓝：微震
  }
  if (mag < 2.5) {
    return const Color(0xFF2FA8E1); // 蓝
  }
  if (mag < 3.5) {
    return const Color(0xFF22B07D); // 绿
  }
  if (mag < 4.5) {
    return const Color(0xFFE0B32A); // 金黄
  }
  if (mag < 5.5) {
    return const Color(0xFFF5A623); // 橙
  }
  if (mag < 6.5) {
    return const Color(0xFFF0603C); // 橙红
  }
  return const Color(0xFFD62828); // 红：巨大地震
}

/// 图例分档（与 magnitudeColor 一一对应）。
const _magnitudeBands = <(String, double)>[
  ('<1.5', 1.0),
  ('1.5', 1.5),
  ('2.5', 2.5),
  ('3.5', 3.5),
  ('4.5', 4.5),
  ('5.5', 5.5),
  ('6.5+', 6.5),
];

/// 地震 / 海啸列表。数据来自 App 直连 USGS 与 tsunami.gov（第二链路），
/// 不依赖云主机和 ntfy，云主机挂了也能看。
class EventListPage extends HookConsumerWidget {
  const new({super.key, this.initialTab = 0});

  /// 打开时落到第几个标签：0 地震，1 海啸公报。
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.eventListTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: s.tabQuakes),
              Tab(text: s.tabTsunami),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_QuakeTab(), _TsunamiTab()],
        ),
      ),
    );
  }
}

class _QuakeTab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designSystem = context.designSystem;
    final colorTheme = designSystem.colorTheme;
    final s = ref.watch(appStringsProvider);
    final async = ref.watch(usgsEventsProvider);

    // 手动刷新：清掉轮询写回的实时快照后重新拉，否则会直接用旧快照。
    Future<void> refreshNow() async {
      ref.read(liveUsgsEventsProvider.notifier).write(null);
      ref.read(liveTsunamiBulletinsProvider.notifier).write(null);
      ref.invalidate(usgsEventsProvider);
      ref.invalidate(tsunamiBulletinsProvider);
      await ref.read(usgsEventsProvider.future);
    }

    return RefreshIndicator(
      onRefresh: refreshNow,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, size: 36),
                  const SizedBox(height: 12),
                  Text('${s.loadFailedUsgs}：$error'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: refreshNow,
                    child: Text(s.retry),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (events) {
          if (events.isEmpty) {
            return Center(child: Text(s.listEmptyQuakes));
          }
          return Column(
            children: [
              const _MagnitudeLegend(),
              Expanded(
                child: ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final color = magnitudeColor(event.magnitude);
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: color, width: 4),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.14),
                    child: Text(
                      event.magnitudeLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    event.place,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_formatTime(event.time)}'
                    '${event.pagerAlert == null ? '' : ' · PAGER ${event.pagerAlert}'}'
                    '${event.tsunami == 1 ? ' · 🌊' : ''}',
                    style: TextStyle(color: colorTheme.onSurfaceVariant),
                  ),
                  trailing: Icon(Icons.chevron_right, size: 18, color: color),
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('${event.magnitudeLabel} ${event.place}'),
                        content: Text(
                          '${s.detailTime}：${_formatTime(event.time)}\n'
                          '${s.detailPager}：${event.pagerAlert ?? s.valueNone}\n'
                          '${s.detailTsunamiEval}：'
                          '${event.tsunami == 1 ? s.valueYes : s.valueNo}\n'
                          '${s.detailEventId}：${event.id}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(s.close),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 震级颜色图例，让用户一眼看懂列表左侧色条。
class _MagnitudeLegend extends StatelessWidget {
  const _MagnitudeLegend();

  @override
  Widget build(BuildContext context) {
    final colorTheme = context.designSystem.colorTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorTheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: colorTheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'M',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorTheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final band in _magnitudeBands)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: magnitudeColor(band.$2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  band.$1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TsunamiTab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final language = ref.watch(appLocaleProvider).languageCode;
    final async = ref.watch(tsunamiBulletinsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tsunamiBulletinsProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, size: 36),
                  const SizedBox(height: 12),
                  Text('${s.loadFailedTsunami}：$error'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(tsunamiBulletinsProvider),
                    child: Text(s.retry),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (bulletins) {
          if (bulletins.isEmpty) {
            return Center(child: Text(s.listEmptyTsunami));
          }
          return ListView.separated(
            itemCount: bulletins.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final bulletin = bulletins[index];
              final color = tsunamiCategoryColor(bulletin.category);
              return Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: color, width: 4)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.14),
                    child: Icon(Icons.waves, color: color),
                  ),
                  title: Text(
                    bulletin.regionLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${tsunamiCategoryLabel(bulletin.category, language)}'
                    '${bulletin.updated == null ? '' : ' · ${_formatTime(bulletin.updated!)}'}',
                  ),
                  trailing: Icon(Icons.chevron_right, size: 18, color: color),
                  onTap: () => showTsunamiBulletinDetail(
                    context,
                    bulletin,
                    language: language,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _formatTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
