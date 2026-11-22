import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:eqmonitor/core/fcm/local_notification_repository.dart';
import 'package:eqmonitor/core/filter/push_filter.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
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

class TsunamiBulletin {
  const TsunamiBulletin({
    required this.id,
    required this.title,
    required this.updated,
    required this.link,
  });

  final String id;
  final String title;
  final DateTime? updated;
  final String link;

  bool get isSevere {
    final t = title.toLowerCase();
    return t.contains('warning') || t.contains('threat') || title.contains('警报');
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
        final title = entry.getElement('title')?.innerText.trim() ?? '海啸公报';
        final updatedRaw = entry.getElement('updated')?.innerText.trim();
        final link = entry
                .findAllElements('link')
                .map((e) => e.getAttribute('href'))
                .whereType<String>()
                .firstOrNull ??
            '';
        bulletins.add(
          TsunamiBulletin(
            id: id.isEmpty ? '$url#$title' : id,
            title: title,
            updated: updatedRaw == null ? null : DateTime.tryParse(updatedRaw)?.toLocal(),
            link: link,
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

final usgsEventsProvider = FutureProvider<List<UsgsEvent>>((ref) async {
  return fetchUsgsEvents();
});

final tsunamiBulletinsProvider = FutureProvider<List<TsunamiBulletin>>((ref) async {
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
}

/// 直连轮询看门狗：开机首轮只登记，之后出现新事件才弹通知。
final directFeedWatcherProvider = Provider<DirectFeedWatcher>((ref) {
  final repository = ref.watch(localNotificationRepositoryProvider);
  final watcher = DirectFeedWatcher(repository: repository);
  ref.onDispose(watcher.dispose);
  return watcher;
});

final directFeedStatusProvider = StreamProvider<DirectFeedStatus>((ref) {
  return ref.watch(directFeedWatcherProvider).status;
});

class DirectFeedWatcher {
  DirectFeedWatcher({required this.repository});

  final LocalNotificationRepository repository;

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
      _emit(.ok);
      final isEn = AppLocaleSetting.value.languageCode == 'en';
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
              ? (isEn
                  ? '🚨 ${event.magnitudeLabel} strong quake: ${event.place}'
                  : '🚨 ${event.magnitudeLabel} 强震：${event.place}')
              : (isEn
                  ? '🌍 ${event.magnitudeLabel} earthquake: ${event.place}'
                  : '🌍 ${event.magnitudeLabel} 地震：${event.place}'),
          body: isEn
              ? 'Time ${_formatTime(event.time)}\n'
                  'Source USGS direct feed (link 2)\n'
                  '${event.url}'
              : '时间 ${_formatTime(event.time)}\n'
                  '来源 USGS 直连（第二链路）\n'
                  '${event.url}',
          channelId: 'global_earthquake',
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
      _emit(.ok);
      final isEn = AppLocaleSetting.value.languageCode == 'en';
      final filter = PushFilterSetting.value;
      for (final bulletin in newest) {
        // 海啸门槛：全部 / 关注级以上 / 只要警报
        if (!filter.allowsTsunami(bulletin.title)) {
          continue;
        }
        await repository.showSimpleNotification(
          title: bulletin.isSevere
              ? (isEn
                  ? '🚨 Tsunami warning: ${bulletin.title}'
                  : '🚨 海啸警报：${bulletin.title}')
              : (isEn
                  ? '🌊 Tsunami bulletin: ${bulletin.title}'
                  : '🌊 海啸公报：${bulletin.title}'),
          body: isEn
              ? 'Source tsunami.gov direct feed (link 2)\n${bulletin.link}'
              : '来源 tsunami.gov 直连（第二链路）\n${bulletin.link}',
          channelId: 'global_tsunami',
          tag: 'direct-${bulletin.id}',
          alert: bulletin.isSevere,
        );
      }
    } on Object {
      _emit(.degraded);
    }
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
