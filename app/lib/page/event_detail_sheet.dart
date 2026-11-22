import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/page/event_list_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// 地震事件详情底部弹窗。
///
/// 列表、首页“最近事件”、以及地图上的震中点都用这同一个弹窗，
/// 保证三处看到的信息完全一致。
Future<void> showUsgsEventDetail(
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
