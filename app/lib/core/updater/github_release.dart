import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// GitHub Releases 更新通道。
///
/// 只做两件事：拉取仓库最新 Release、按 versionCode 和本地安装版本比对；
/// 有新版时提示并跳到 Release 页，不在 App 内下载或安装 APK。
const githubRepoSlug = 'Zero4499/EQMonitor';

const _latestReleaseUrl =
    'https://api.github.com/repos/$githubRepoSlug/releases/latest';

/// 一条 GitHub Release 的摘要信息。
class GithubReleaseInfo {
  const GithubReleaseInfo({
    required this.tagName,
    required this.htmlUrl,
    required this.versionCode,
    this.name,
    this.body,
  });

  final String tagName;
  final String htmlUrl;

  /// 远程 versionCode；解析不到时为 0，调用方需按「> 0 才参与比对」处理。
  final int versionCode;

  final String? name;
  final String? body;

  factory GithubReleaseInfo.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'] is List ? json['assets'] as List : const [];
    var assetCode = 0;
    for (final asset in assets) {
      final map = asset is Map ? asset : const {};
      final assetName = map['name'] as String? ?? '';
      final parsed = GithubReleaseChecker._buildCodeFromAssetName(assetName);
      if (parsed != null && parsed > assetCode) {
        assetCode = parsed;
      }
    }
    final body = json['body'] as String?;
    final bodyCode = GithubReleaseChecker._buildCodeFromBody(body);
    return GithubReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      versionCode: bodyCode ?? assetCode,
      name: json['name'] as String?,
      body: body,
    );
  }
}

/// Release 拉取与 versionCode 解析。
class GithubReleaseChecker {
  const GithubReleaseChecker._();

  static Future<GithubReleaseInfo?> fetchLatest() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(_latestReleaseUrl)).timeout(
            const Duration(seconds: 18),
          );
      request.headers.set('User-Agent', 'QuakePush/1.0');
      request.headers.set('Accept', 'application/vnd.github+json');
      final response = await request.close().timeout(
            const Duration(seconds: 20),
          );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final raw = await response.transform(utf8.decoder).join();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      return GithubReleaseInfo.fromJson(json);
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// 优先读 Release 正文里的 `build: 4012` 一行。
  static int? _buildCodeFromBody(String? body) {
    if (body == null) {
      return null;
    }
    final match = RegExp(r'build:\s*(\d+)').firstMatch(body);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  /// 正文没写 build 行时，从 APK 文件名里的 `-2012-` 段兜底解析。
  static int? _buildCodeFromAssetName(String name) {
    final match = RegExp(r'-(20\d{3})-').firstMatch(name);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }
}
