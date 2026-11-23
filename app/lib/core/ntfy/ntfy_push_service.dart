import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eqmonitor/core/fcm/local_notification_repository.dart';
import 'package:eqmonitor/core/i18n/notification_strings.dart';
import 'package:eqmonitor/feature/notification/data/model/push_history_entry.dart';
import 'package:eqmonitor/core/provider/firebase/firebase_messaging_foreground.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 自建 USGS / tsunami.gov 推送链路。
///
/// 云主机（quake-pusher）轮询 USGS 与 tsunami.gov，把事件发布到 ntfy 主题；
/// 本服务在 App 前台订阅同一主题的 JSON 流，收到消息后直接弹本地通知。
/// 不依赖 FCM，因此在没有 Google 服务的环境里也能工作。
const ntfyServerUrl = 'https://ntfy.sh';
const ntfyTopic = 'quake-52e3e857741b43fb';

/// 本地时间格式化为 `yyyy-MM-dd HH:mm`，测试通知正文不再直接显示 ISO 串。
String _formatNow() {
  final t = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}

enum NtfyPushStatus {
  idle,
  connecting,
  connected,
  disconnected;

  String get label => switch (this) {
    .idle => '未启动',
    .connecting => '连接中…',
    .connected => '已连接 · 实时接收',
    .disconnected => '已断开 · 稍后自动重连',
  };

  String get labelEn => switch (this) {
    .idle => 'Not started',
    .connecting => 'Connecting…',
    .connected => 'Connected · live',
    .disconnected => 'Disconnected · retrying',
  };

  String get labelJa => switch (this) {
    .idle => '未開始',
    .connecting => '接続中…',
    .connected => '接続済み・リアルタイム受信',
    .disconnected => '切断・自動再接続',
  };

  String displayLabel(String language) => switch (language) {
    'en' => labelEn,
    'ja' => labelJa,
    _ => label,
  };
}

final ntfyPushServiceProvider = Provider<NtfyPushService>((ref) {
  final repository = ref.watch(localNotificationRepositoryProvider);
  final service = NtfyPushService(repository: repository);
  ref.onDispose(service.dispose);
  return service;
});

final ntfyPushStatusProvider = StreamProvider<NtfyPushStatus>((ref) {
  final service = ref.watch(ntfyPushServiceProvider);
  return service.status;
});

class NtfyPushService {
  NtfyPushService({required this.repository});

  final LocalNotificationRepository repository;

  final _statusController = StreamController<NtfyPushStatus>.broadcast();
  NtfyPushStatus _lastStatus = .idle;
  HttpClient? _client;
  bool _running = false;
  int _received = 0;

  Stream<NtfyPushStatus> get status async* {
    yield _lastStatus;
    yield* _statusController.stream;
  }

  NtfyPushStatus get currentStatus => _lastStatus;
  int get receivedCount => _received;

  void _emit(NtfyPushStatus status) {
    _lastStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    unawaited(_loop());
  }

  Future<void> _loop() async {
    var backoff = const Duration(seconds: 2);
    while (_running) {
      try {
        _emit(.connecting);
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 12)
          ..idleTimeout = const Duration(minutes: 5);
        _client = client;
        final request = await client.getUrl(
          Uri.parse('$ntfyServerUrl/$ntfyTopic/json'),
        );
        request.headers.set('Accept', 'application/x-ndjson');
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          _emit(.disconnected);
          await response.drain<void>();
          throw HttpException('ntfy ${response.statusCode}');
        }
        _emit(.connected);
        backoff = const Duration(seconds: 2);
        await for (final line
            in response
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (!_running) {
            break;
          }
          _handleLine(line);
        }
        if (_running) {
          _emit(.disconnected);
        }
      } on Object {
        _emit(.disconnected);
      } finally {
        _client?.close(force: true);
        _client = null;
      }
      if (!_running) {
        break;
      }
      await Future<void>.delayed(backoff);
      final next = backoff.inSeconds * 2;
      backoff = Duration(seconds: next > 60 ? 60 : next);
    }
    _emit(.idle);
  }

  void _handleLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }
    Map<String, Object?> json;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, Object?>) {
        return;
      }
      json = decoded;
    } on FormatException {
      return;
    }
    if (json['event'] != 'message') {
      return;
    }
    final title = (json['title'] as String?)?.trim();
    final message = (json['message'] as String?)?.trim();
    if ((title == null || title.isEmpty) && (message == null || message.isEmpty)) {
      return;
    }
    _received++;
    final isTsunami =
        (title?.contains('🌊') ?? false) || (title?.contains('海啸') ?? false);
    final effectiveTitle = title != null && title.isNotEmpty
        ? title
        : notifFallbackQuakeTitle();
    // 云主机已按规则映射：M7+ / PAGER red / 海啸 Warning・Threat → priority 5
    final priority = (json['priority'] as num?)?.toInt() ?? 3;
    unawaited(
      repository.showSimpleNotification(
        title: effectiveTitle,
        body: _stripMarkdown(message ?? ''),
        channelId: isTsunami ? 'global_tsunami_v3' : 'global_earthquake_v3',
        tag: json['id'] as String?,
        alert: priority >= 5,
        source: PushHistorySource.ntfy,
      ),
    );
  }

  /// 端到端测试：把一条测试消息发布到 ntfy 主题，
  /// 服务器会把它广播回来，本机订阅流收到后弹出通知。
  Future<bool> sendEndToEndTest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.postUrl(Uri.parse(ntfyServerUrl));
      request.headers.contentType = ContentType.json;
      final now = _formatNow();
      request.write(
        jsonEncode({
          'topic': ntfyTopic,
          'title': notifE2eTitle(),
          'message': notifE2eMessage(now),
          'priority': 4,
          'tags': ['test_tube'],
        }),
      );
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode == HttpStatus.ok;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// 本地测试：不经过网络，直接弹一条本地通知，用来验证
  /// 通知权限 / 通道 / 声音是否正常。
  Future<void> showLocalTest() => repository.showSimpleNotification(
    title: notifLocalTestTitle(),
    body: notifLocalTestBody(_formatNow()),
    channelId: 'global_earthquake_v3',
    tag: 'local-test',
  );

  /// 警报级测试：全屏 + 闹钟音量 + 持续通知，验证 M7+ / 海啸警报的弹出方式。
  Future<void> showAlertTest() => repository.showSimpleNotification(
    title: notifAlertTestTitle(),
    body: notifAlertTestBody(_formatNow()),
    tag: 'alert-test',
    alert: true,
  );

  /// 按渠道试听：直接弹一条指定分级渠道的本地通知，用来核对该渠道的
  /// 提示音 / 振动节奏 / 呼吸灯颜色。[alert] 对应全屏 + 闹钟音量。
  Future<void> showChannelTest({
    required String channelId,
    bool alert = false,
  }) => repository.showSimpleNotification(
    title: notifLocalTestTitle(),
    body: notifLocalTestBody(_formatNow()),
    channelId: channelId,
    tag: 'channel-test-$channelId',
    alert: alert,
  );

  void dispose() {
    _running = false;
    _client?.close(force: true);
    unawaited(_statusController.close());
  }

  static String _stripMarkdown(String raw) => raw
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
        (match) => '${match[1]} (${match[2]})',
      )
      .replaceAll(RegExp(r'\*\*|\*|__|`|~~'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
