import 'package:collection/collection.dart';

/// 推送历史条目：本地固化的一条已下发通知记录。
///
/// 不依赖上游后端，纯本地 JSON 落盘；字段对齐通知下发时可用到的信息。
enum PushHistoryKind {
  /// 地震推送
  quake,

  /// 海啸公报
  tsunami,

  /// 本机 / 端到端 / 渠道试听等测试通知
  test,

  /// 其余 / 未分类
  other,
}

enum PushHistorySource {
  /// App 直连 USGS / tsunami.gov 轮询
  direct,

  /// 云主机 → ntfy 推送
  ntfy,

  /// Firebase Cloud Messaging
  fcm,

  /// 来源未知
  other,
}

class PushHistoryEntry {
  const PushHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.body,
    this.channelId,
    this.alert = false,
    this.kind = PushHistoryKind.other,
    this.source = PushHistorySource.other,
    this.url,
  });

  /// 去重用标识：通知 tag 优先，否则标题+正文的哈希。
  final String id;

  /// 下发时刻，epoch 毫秒。
  final int timestamp;

  final String title;
  final String body;
  final String? channelId;
  final bool alert;
  final PushHistoryKind kind;
  final PushHistorySource source;
  final String? url;

  factory PushHistoryEntry.fromJson(Map<String, Object?> json) {
    final kindRaw = json['kind'] as String?;
    final sourceRaw = json['source'] as String?;
    return PushHistoryEntry(
      id: (json['id'] as String? ?? ''),
      timestamp: (json['timestamp'] as num? ?? 0).toInt(),
      title: (json['title'] as String? ?? ''),
      body: (json['body'] as String? ?? ''),
      channelId: json['channelId'] as String?,
      alert: json['alert'] as bool? ?? false,
      kind: PushHistoryKind.values
          .where((e) => e.name == kindRaw)
          .firstOrNull ??
          PushHistoryKind.other,
      source: PushHistorySource.values
          .where((e) => e.name == sourceRaw)
          .firstOrNull ??
          PushHistorySource.other,
      url: json['url'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'timestamp': timestamp,
    'title': title,
    'body': body,
    'channelId': channelId,
    'alert': alert,
    'kind': kind.name,
    'source': source.name,
    'url': url,
  };
}
