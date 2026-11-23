import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:eqmonitor/core/fcm/local_notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:eqmonitor/core/filter/push_filter.dart';
import 'package:eqmonitor/core/i18n/notification_strings.dart';
import 'package:eqmonitor/core/i18n/tri.dart';
import 'package:eqmonitor/core/provider/firebase/firebase_messaging_foreground.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:xml/xml.dart';

/// 第二链路：App 直接读 USGS / tsunami.gov 官方源。
///
/// 主链路是云主机 quake-pusher → ntfy；云主机挂了或 ntfy 不可用时，
/// 这条直连链路仍然能自己拉数据、自己弹通知，同时供列表页使用。
const usgsFeedUrl =
    'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson';

const tsunamiFeedUrls = <String>[
  'https://www.tsunami.gov/events/xml/PHEBAtom.xml',
  'https://www.tsunami.gov/events/xml/PAAQAtom.xml',
];

class UsgsEvent {
  const UsgsEvent({
    required this.id,
    required this.magnitude,
    required this.place,
    required this.time,
    required this.url,
    required this.pagerAlert,
    required this.tsunami,
    this.latitude,
    this.longitude,
  });

  final String id;
  final double? magnitude;
  final String place;
  final DateTime time;
  final String url;
  final String? pagerAlert;
  final int tsunami;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  bool get isMajor => (magnitude ?? 0) >= 7 || pagerAlert == 'red';

  String get magnitudeLabel =>
      magnitude == null ? '—' : 'M${magnitude!.toStringAsFixed(1)}';
}

/// 海啸公报分级。Category 解析自 summary XHTML；解析不到时回退标题关键词。
enum TsunamiCategory {
  /// Warning / Threat：红色警报级。
  warning,

  /// Watch / Advisory：橙色关注级。
  advisory,

  /// Information / Statement：蓝色信息级。
  info,

  /// 未识别。
  unknown;

  /// 严重级：走全屏 + 闹钟通知渠道。
  bool get isSevere => this == .warning;
}

/// CAP 1.2 报文的消息类型：Alert 首发 / Update 更新 / Cancel 撤销。
enum TsunamiMsgType {
  alert,
  update,
  cancel,
  unknown;

  static TsunamiMsgType parse(String? raw) {
    return switch ((raw ?? '').toLowerCase().trim()) {
      'alert' => .alert,
      'update' => .update,
      'cancel' => .cancel,
      _ => .unknown,
    };
  }
}

/// CAP 消息类型的本地化标签。
String tsunamiMsgTypeLabel(TsunamiMsgType type, String language) =>
    switch (type) {
      .alert => tri3(language, zh: '首发', en: 'Alert', ja: '発表'),
      .update => tri3(language, zh: '更新', en: 'Update', ja: '更新'),
      .cancel => tri3(language, zh: '已撤销', en: 'Cancelled', ja: '取消'),
      .unknown => '',
    };

TsunamiCategory parseTsunamiCategory(String? categoryRaw, String title) {
  final c = (categoryRaw ?? '').toLowerCase();
  final t = title.toLowerCase();
  bool has(String k) => c.contains(k) || t.contains(k);
  if (has('warning') || has('threat')) {
    return .warning;
  }
  if (has('watch') || has('advisory')) {
    return .advisory;
  }
  if (has('information') || has('statement') || has('info')) {
    return .info;
  }
  return .unknown;
}

/// 公报分级配色：Warning/Threat 红，Watch/Advisory 橙，其余蓝。
Color tsunamiCategoryColor(TsunamiCategory category) => switch (category) {
  .warning => const Color(0xFFD62828),
  .advisory => const Color(0xFFF5A623),
  .info => const Color(0xFF2FA8E1),
  .unknown => const Color(0xFF2FA8E1),
};

/// 公报分级的本地化标签。
String tsunamiCategoryLabel(TsunamiCategory category, String language) =>
    switch (category) {
      .warning => tri3(language, zh: '海啸警报', en: 'Tsunami warning', ja: '津波警報'),
      .advisory => tri3(language, zh: '海啸关注', en: 'Tsunami advisory', ja: '津波注意報'),
      .info => tri3(language, zh: '海啸信息', en: 'Information', ja: '津波情報'),
      .unknown => tri3(language, zh: '公报', en: 'Bulletin', ja: '情報'),
    };

class TsunamiBulletin {
  const TsunamiBulletin({
    required this.id,
    required this.title,
    required this.updated,
    required this.link,
    required this.category,
    this.categoryRaw,
    this.latitude,
    this.longitude,
    this.magnitude,
    this.region,
    this.note,
    this.capLink,
    this.expires,
    this.msgType,
  });

  final String id;

  /// Atom 条目标题（真实 feed 里通常是受影响地区名）。
  final String title;
  final DateTime? updated;
  final String link;
  final TsunamiCategory category;
  final String? categoryRaw;
  final double? latitude;
  final double? longitude;
  final String? magnitude;
  final String? region;
  final String? note;

  /// 关联的 CAP 1.2 报文链接（Atom 的 cap+xml 链接），用于解析有效期与撤销状态。
  final String? capLink;

  /// CAP `<expires>`：本公报的失效时间（本地时间）。Atom feed 本身不带这个字段。
  final DateTime? expires;

  /// CAP `<msgType>`：Alert / Update / Cancel。
  final TsunamiMsgType? msgType;

  bool get hasLocation => latitude != null && longitude != null;

  bool get isSevere => category.isSevere;

  /// 公报被官方撤销（CAP msgType = Cancel）。
  bool get isCancelled => msgType == TsunamiMsgType.cancel;

  /// 已过 CAP 有效期。
  bool get isExpired => expires != null && expires!.isBefore(DateTime.now());

  /// 展示用地区名：summary 里的 Affected Region 优先，回退条目标题。
  String get regionLabel => (region?.trim().isNotEmpty ?? false) ? region!.trim() : title;

  TsunamiBulletin copyWith({
    DateTime? expires,
    TsunamiMsgType? msgType,
  }) {
    return TsunamiBulletin(
      id: id,
      title: title,
      updated: updated,
      link: link,
      category: category,
      categoryRaw: categoryRaw,
      latitude: latitude,
      longitude: longitude,
      magnitude: magnitude,
      region: region,
      note: note,
      capLink: capLink,
      expires: expires ?? this.expires,
      msgType: msgType ?? this.msgType,
    );
  }
}

Future<List<UsgsEvent>> fetchUsgsEvents() async {
  final body = await _getString(usgsFeedUrl);
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, Object?>) {
    return const [];
  }
  final features = decoded['features'];
  if (features is! List) {
    return const [];
  }
  final events = <UsgsEvent>[];
  for (final feature in features) {
    if (feature is! Map<String, Object?>) {
      continue;
    }
    final props = feature['properties'];
    if (props is! Map<String, Object?>) {
      continue;
    }
    final id = feature['id'];
    if (id is! String) {
      continue;
    }
    final mag = props['mag'];
    final timeMs = props['time'];
    double? lat;
    double? lon;
    final geometry = feature['geometry'];
    if (geometry is Map<String, Object?>) {
      final coords = geometry['coordinates'];
      if (coords is List && coords.length >= 2) {
        final lonRaw = coords[0];
        final latRaw = coords[1];
        if (latRaw is num && lonRaw is num) {
          lat = latRaw.toDouble();
          lon = lonRaw.toDouble();
        }
      }
    }
    events.add(
      UsgsEvent(
        id: id,
        magnitude: mag is num ? mag.toDouble() : null,
        place: (props['place'] as String?)?.trim() ?? '位置未知',
        time: timeMs is num
            ? DateTime.fromMillisecondsSinceEpoch(
                timeMs.toInt(),
                isUtc: true,
              ).toLocal()
            : DateTime.now(),
        url: (props['url'] as String?) ?? '',
        pagerAlert: props['alert'] as String?,
        tsunami: (props['tsunami'] as num?)?.toInt() ?? 0,
        latitude: lat,
        longitude: lon,
      ),
    );
  }
  events.sort((a, b) => b.time.compareTo(a.time));
  return events;
}

Future<List<TsunamiBulletin>> fetchTsunamiBulletins() async {
  final bulletins = <TsunamiBulletin>[];
  for (final url in tsunamiFeedUrls) {
    try {
      final body = await _getString(url);
      final doc = XmlDocument.parse(body);
      for (final entry in doc.findAllElements('entry')) {
        final id = entry.getElement('id')?.innerText.trim() ?? '';
        final title = _unescapeHtml(
          entry.getElement('title')?.innerText.trim() ?? 'Tsunami bulletin',
        );
        final updatedRaw = entry.getElement('updated')?.innerText.trim();
        final link = entry
                .findAllElements('link')
                .map((e) => e.getAttribute('href'))
                .whereType<String>()
                .firstOrNull ??
            '';
        final capLink = entry
                .findAllElements('link')
                .where(
                  (e) =>
                      e.getAttribute('type') == 'application/cap+xml' ||
                      (e.getAttribute('title') ?? '').toUpperCase().contains('CAP'),
                )
                .map((e) => e.getAttribute('href'))
                .whereType<String>()
                .firstOrNull;
        final summaryHtml =
            entry.findElements('summary').firstOrNull?.innerXml ?? '';
        final categoryRaw = _matchSummaryField(summaryHtml, 'Category');
        final magnitude = _matchSummaryField(summaryHtml, 'Preliminary Magnitude');
        final region = _matchSummaryField(summaryHtml, 'Affected Region');
        final note = _extractSummaryNote(summaryHtml);
        double? lat;
        double? lon;
        for (final node in entry.descendants.whereType<XmlElement>()) {
          if (node.localName == 'lat') {
            lat = double.tryParse(node.innerText.trim());
          } else if (node.localName == 'long') {
            lon = double.tryParse(node.innerText.trim());
          }
        }
        bulletins.add(
          TsunamiBulletin(
            id: id.isEmpty ? '$url#$title' : id,
            title: title,
            updated: updatedRaw == null
                ? null
                : DateTime.tryParse(updatedRaw)?.toLocal(),
            link: link,
            category: parseTsunamiCategory(categoryRaw, title),
            categoryRaw: categoryRaw,
            latitude: lat,
            longitude: lon,
            magnitude: magnitude == null ? null : _unescapeHtml(magnitude),
            region: region == null ? null : _unescapeHtml(region),
            note: note == null ? null : _unescapeHtml(note),
            capLink: capLink,
          ),
        );
      }
    } on Object {
      // 单个源失败不影响另一个源和列表展示
    }
  }
  bulletins.sort((a, b) {
    final at = a.updated ?? DateTime(1970);
    final bt = b.updated ?? DateTime(1970);
    return bt.compareTo(at);
  });
  return bulletins;
}

/// 拉取公报关联的 CAP 1.2 报文，补全有效期（`<expires>`）与消息类型（`<msgType>`）。
/// Atom feed 本身不带结束时间，只有 CAP 里有；失败时原样返回，不影响列表展示。
Future<TsunamiBulletin> fetchTsunamiCapDetails(TsunamiBulletin bulletin) async {
  final url = bulletin.capLink;
  if (url == null || url.isEmpty) {
    return bulletin;
  }
  try {
    final body = await _getString(url);
    final doc = XmlDocument.parse(body);
    final msgTypeRaw = doc.findAllElements('msgType').firstOrNull?.innerText.trim();
    final expiresRaw = doc.findAllElements('expires').firstOrNull?.innerText.trim();
    final expires = expiresRaw == null
        ? null
        : DateTime.tryParse(expiresRaw)?.toLocal();
    return bulletin.copyWith(
      expires: expires,
      msgType: TsunamiMsgType.parse(msgTypeRaw),
    );
  } on Object {
    return bulletin;
  }
}

/// 从 summary XHTML 里取 `<strong>Label:</strong> 值` 形式的字段。
String? _matchSummaryField(String html, String label) {
  final match = RegExp(
    '$label\\s*:?\\s*</strong>\\s*([^<\\n]+)',
    caseSensitive: false,
  ).firstMatch(html);
  final value = match?.group(1)?.trim();
  return (value == null || value.isEmpty) ? null : value;
}

String? _extractSummaryNote(String html) {
  final match = RegExp(
    r'<b>Note:</b>\s*(.*?)(?:<strong>Definition|$)',
    dotAll: true,
    caseSensitive: false,
  ).firstMatch(html);
  final raw = match?.group(1);
  if (raw == null) return null;
  final text = _stripHtmlTags(raw).trim();
  return text.isEmpty ? null : text;
}

String _stripHtmlTags(String html) => html
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// 解码 summary XHTML 里残留的 HTML 实体（如 `&amp;` `&lt;`）。
String _unescapeHtml(String text) => text
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ');

Future<String> _getString(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(
      const Duration(seconds: 18),
    );
    request.headers.set('User-Agent', 'QuakePush/1.0');
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode} @ $url');
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

/// 直连轮询写回的实时快照：列表 / 地图读它，所以不用等下一次冷启动。
class LiveUsgsEventsNotifier extends Notifier<List<UsgsEvent>?> {
  @override
  List<UsgsEvent>? build() => null;

  void write(List<UsgsEvent>? events) => state = events;
}

final liveUsgsEventsProvider =
    NotifierProvider<LiveUsgsEventsNotifier, List<UsgsEvent>?>(
      LiveUsgsEventsNotifier.new,
    );

class LiveTsunamiBulletinsNotifier extends Notifier<List<TsunamiBulletin>?> {
  @override
  List<TsunamiBulletin>? build() => null;

  void write(List<TsunamiBulletin>? bulletins) => state = bulletins;
}

final liveTsunamiBulletinsProvider =
    NotifierProvider<LiveTsunamiBulletinsNotifier, List<TsunamiBulletin>?>(
      LiveTsunamiBulletinsNotifier.new,
    );

/// 最近一次成功拉取数据的时间（本机时间），界面用它显示「更新于 …」。
class FeedLastSyncedNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void markNow() => state = DateTime.now();
}

final feedLastSyncedAtProvider =
    NotifierProvider<FeedLastSyncedNotifier, DateTime?>(FeedLastSyncedNotifier.new);

final usgsEventsProvider = FutureProvider<List<UsgsEvent>>((ref) async {
  final live = ref.watch(liveUsgsEventsProvider);
  if (live != null) {
    return live;
  }
  return fetchUsgsEvents();
});

final tsunamiBulletinsProvider =
    FutureProvider<List<TsunamiBulletin>>((ref) async {
      final live = ref.watch(liveTsunamiBulletinsProvider);
      if (live != null) {
        return live;
      }
      return fetchTsunamiBulletins();
    });

enum DirectFeedStatus {
  idle,
  ok,
  degraded;

  String get label => switch (this) {
    .idle => '未启动',
    .ok => '直连正常',
    .degraded => '直连异常',
  };

  String get labelEn => switch (this) {
    .idle => 'Not started',
    .ok => 'Direct feed OK',
    .degraded => 'Direct feed error',
  };

  String get labelJa => switch (this) {
    .idle => '未開始',
    .ok => '直結正常',
    .degraded => '直結エラー',
  };

  String displayLabel(String language) => switch (language) {
    'en' => labelEn,
    'ja' => labelJa,
    _ => label,
  };
}

/// 直连轮询看门狗：开机首轮只登记，之后出现新事件才弹通知。
/// 同时把每轮抓到的数据写回实时快照，让主页列表 / 地图跟着刷新。
final directFeedWatcherProvider = Provider<DirectFeedWatcher>((ref) {
  final repository = ref.watch(localNotificationRepositoryProvider);
  final watcher = DirectFeedWatcher(
    repository: repository,
    onQuakes: (events) {
      ref.read(liveUsgsEventsProvider.notifier).write(events);
      ref.read(feedLastSyncedAtProvider.notifier).markNow();
    },
    onTsunami: (bulletins) {
      ref.read(liveTsunamiBulletinsProvider.notifier).write(bulletins);
      ref.read(feedLastSyncedAtProvider.notifier).markNow();
    },
  );
  ref.onDispose(watcher.dispose);
  return watcher;
});

final directFeedStatusProvider = StreamProvider<DirectFeedStatus>((ref) {
  return ref.watch(directFeedWatcherProvider).status;
});

class DirectFeedWatcher {
  DirectFeedWatcher({
    required this.repository,
    this.onQuakes,
    this.onTsunami,
  });

  final LocalNotificationRepository repository;

  /// 每轮抓取成功后回调，供界面拿到最新数据。
  final void Function(List<UsgsEvent> events)? onQuakes;
  final void Function(List<TsunamiBulletin> bulletins)? onTsunami;

  final _statusController = StreamController<DirectFeedStatus>.broadcast();
  DirectFeedStatus _last = .idle;
  final Set<String> _seenQuakes = {};
  final Set<String> _seenTsunami = {};
  Timer? _quakeTimer;
  Timer? _tsunamiTimer;

  Stream<DirectFeedStatus> get status async* {
    yield _last;
    yield* _statusController.stream;
  }

  void _emit(DirectFeedStatus status) {
    _last = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void start() {
    if (_quakeTimer != null) {
      return;
    }
    _emit(.ok);
    unawaited(_pollQuakes(initial: true));
    unawaited(_pollTsunami(initial: true));
    _quakeTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => unawaited(_pollQuakes(initial: false)),
    );
    _tsunamiTimer = Timer.periodic(
      const Duration(seconds: 180),
      (_) => unawaited(_pollTsunami(initial: false)),
    );
  }

  Future<void> _pollQuakes({required bool initial}) async {
    try {
      final events = await fetchUsgsEvents();
      var newest = const <UsgsEvent>[];
      if (!initial) {
        newest = events.where((e) => !_seenQuakes.contains(e.id)).toList();
      }
      _seenQuakes.addAll(events.map((e) => e.id));
      onQuakes?.call(events);
      _emit(.ok);
      final filter = PushFilterSetting.value;
      for (final event in newest) {
        // 推送条件在设置页里可调：震级下限 / 只推警报级
        if (!filter.allowsQuake(
          magnitude: event.magnitude,
          major: event.isMajor,
        )) {
          continue;
        }
        await repository.showSimpleNotification(
          title: event.isMajor
              ? notifQuakeMajorTitle(event.magnitudeLabel, event.place)
              : notifQuakeNormalTitle(event.magnitudeLabel, event.place),
          body: notifQuakeBody(_formatTime(event.time), event.url),
          channelId: _quakeChannelId(event.magnitude, event.isMajor),
          tag: 'direct-${event.id}',
          alert: event.isMajor,
        );
      }
    } on Object {
      _emit(.degraded);
    }
  }

  Future<void> _pollTsunami({required bool initial}) async {
    try {
      final bulletins = await fetchTsunamiBulletins();
      var newest = const <TsunamiBulletin>[];
      if (!initial) {
        newest = bulletins.where((b) => !_seenTsunami.contains(b.id)).toList();
      }
      _seenTsunami.addAll(bulletins.map((b) => b.id));
      onTsunami?.call(bulletins);
      _emit(.ok);
      final filter = PushFilterSetting.value;
      for (final bulletin in newest) {
        // 海啸门槛：全部 / 关注级以上 / 只要警报
        if (!filter.allowsTsunami(bulletin.category)) {
          continue;
        }
        await repository.showSimpleNotification(
          title: bulletin.isSevere
              ? notifTsunamiSevereTitle(bulletin.regionLabel)
              : notifTsunamiNormalTitle(bulletin.regionLabel),
          body: notifTsunamiBody(bulletin.link),
          channelId: 'global_tsunami_v3',
          tag: 'direct-${bulletin.id}',
          alert: bulletin.isSevere,
        );
      }
    } on Object {
      _emit(.degraded);
    }
  }

  /// 按震级 / 警报等级选地震渠道（绑定不同提示音）：M8.0+ → m8 渠道，
  /// M7.0–7.9 或 PAGER red → m7 渠道，其余 → 普通地震渠道。
  String _quakeChannelId(double? magnitude, bool major) {
    if (magnitude != null && magnitude >= 8) {
      return 'global_earthquake_m8_v3';
    }
    if ((magnitude != null && magnitude >= 7) || major) {
      return 'global_earthquake_m7_v3';
    }
    return 'global_earthquake_v3';
  }

  String _formatTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }

  void dispose() {
    _quakeTimer?.cancel();
    _tsunamiTimer?.cancel();
    unawaited(_statusController.close());
  }
}
