import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/i18n/tri.dart';
import 'package:eqmonitor/page/event_list_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// 地震事件详情底部弹窗。
///
/// 列表、首页"最近事件"、以及地图上的震中点都用这同一个弹窗，
/// 保证三处看到的信息完全一致。
Future<void> showUsgsEventDetail(
  BuildContext context,
  UsgsEvent event, {
  required String language,
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
                    label: Text(
                      tri3(
                        language,
                        zh: '海啸标记',
                        en: 'Tsunami flag',
                        ja: '津波フラグ',
                      ),
                    ),
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
              _formatLocalTime(event.time),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${tri3(language, zh: '坐标', en: 'Coordinates', ja: '座標')} '
              '${event.latitude!.toStringAsFixed(3)}, '
              '${event.longitude!.toStringAsFixed(3)} · '
              'PAGER ${event.pagerAlert ?? tri3(language, zh: '无', en: 'none', ja: 'なし')}',
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
                    label: Text(
                      tri3(
                        language,
                        zh: '打开 USGS 详情',
                        en: 'Open in USGS',
                        ja: 'USGS の詳細を開く',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async => Navigator.of(context).pop(),
                  child: Text(
                    tri3(
                      language,
                      zh: '关闭',
                      en: 'Close',
                      ja: '閉じる',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 海啸公报详情底部弹窗。
///
/// 列表行、主页横幅、地图海啸标记都走这同一个弹窗。
Future<void> showTsunamiBulletinDetail(
  BuildContext context,
  TsunamiBulletin bulletin, {
  required String language,
}) async {
  final colorTheme = context.designSystem.colorTheme;
  final color = tsunamiCategoryColor(bulletin.category);
  final s = AppStrings.of(Locale(language));
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: FutureBuilder<TsunamiBulletin>(
          future: fetchTsunamiCapDetails(bulletin),
          initialData: bulletin,
          builder: (context, snapshot) {
            final b = snapshot.data ?? bulletin;
            final two = (int v) => v.toString().padLeft(2, '0');
            final expiresText = b.expires == null
                ? null
                : '${b.expires!.year}-${two(b.expires!.month)}-${two(b.expires!.day)} '
                    '${two(b.expires!.hour)}:${two(b.expires!.minute)}';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.14),
                      child: Icon(Icons.waves, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Chip(
                        label: Text(
                          tsunamiCategoryLabel(b.category, language),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor: color,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                    ),
                    if (b.isCancelled)
                      Chip(
                        label: Text(
                          tsunamiMsgTypeLabel(TsunamiMsgType.cancel, language),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor: const Color(0xFF6E6E6E),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                    if (b.magnitude != null)
                      Text(
                        _bulletinMagnitudeLabel(b.magnitude!),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  b.regionLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  b.updated == null ? s.timeUnknown : _formatLocalTime(b.updated!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorTheme.onSurfaceVariant,
                  ),
                ),
                if (expiresText != null)
                  Text(
                    '${tri3(language, zh: '有效期至', en: 'Valid until', ja: '有効期限')} '
                    '$expiresText'
                    '${b.isExpired ? tri3(language, zh: '（已失效）', en: ' (expired)', ja: '（期限切れ）') : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: b.isExpired
                          ? colorTheme.onSurfaceVariant
                          : const Color(0xFF2FA8E1),
                    ),
                  ),
                if (b.hasLocation)
                  Text(
                    '${tri3(language, zh: '坐标', en: 'Coordinates', ja: '座標')} '
                    '${b.latitude!.toStringAsFixed(3)}, '
                    '${b.longitude!.toStringAsFixed(3)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorTheme.onSurfaceVariant,
                    ),
                  ),
                if ((b.note ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${s.bulletinNoteLabel}: ${b.note!}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorTheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: b.link.isEmpty
                            ? null
                            : () async => launchUrl(Uri.parse(b.link)),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(s.bulletinOpenLink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async => Navigator.of(context).pop(),
                      child: Text(s.close),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// 海啸公报震级补 M 前缀；源串已带 M / Mw 时不重复加。
String _bulletinMagnitudeLabel(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return raw;
  final first = value.substring(0, 1);
  if (first == 'M' || first == 'm' || first == 'W' || first == 'w') {
    return value;
  }
  return 'M$value';
}

/// 本地时间格式化为 `yyyy-MM-dd HH:mm`，避免直接显示 ISO 串。
String _formatLocalTime(DateTime time) {
  final local = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
