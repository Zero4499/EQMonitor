import 'dart:async';

import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/gen/assets.gen.dart';
import 'package:eqmonitor/core/gen/fonts.gen.dart';
import 'package:eqmonitor/core/filter/push_filter.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/i18n/tri.dart';
import 'package:eqmonitor/core/notification/notification_permissions.dart';
import 'package:eqmonitor/core/provider/firebase/firebase_messaging_foreground.dart';
import 'package:eqmonitor/core/provider/package_info.dart';
import 'package:eqmonitor/core/updater/github_release.dart';
import 'package:eqmonitor/feature/notification/ui/page/push_history_page.dart';
import 'package:eqmonitor/feature/settings/component/settings_section_header.dart';
import 'package:eqmonitor/feature/settings/features/notification_settings/ui/component/usgs_push_tile.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingsPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: ListView(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: .antiAlias,
                  elevation: 4,
                  child: Assets.images.icon.image(fit: .contain),
                ),
              ),
            ),
          ),
          const _AppVersionInformation(),
          SettingsSectionHeader(text: s.settingsNotificationSection),
          M3ESegmentedColumn(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ListTile(
                title: Text(
                  tri3(
                    ref.watch(appLocaleProvider).languageCode,
                    zh: '一键申请全部通知权限',
                    en: 'Grant all notification permissions',
                    ja: '通知権限をまとめて許可',
                  ),
                ),
                subtitle: Text(
                  tri3(
                    ref.watch(appLocaleProvider).languageCode,
                    zh: '通知 · 全屏 intent · 勿扰访问 · 电池白名单',
                    en: 'Notifications · full-screen intent · DND · battery whitelist',
                    ja: '通知 · 全画面 intent · サイレントモード · バッテリー最適化除外',
                  ),
                ),
                leading: const Icon(Icons.verified_user_outlined),
                onTap: () async =>
                    NotificationPermissions.requestAllIfNeeded(force: true),
              ),
              ListTile(
                title: Text(
                  tri3(
                    ref.watch(appLocaleProvider).languageCode,
                    zh: '测试通知',
                    en: 'Test notification',
                    ja: '通知テスト',
                  ),
                ),
                subtitle: Text(
                  tri3(
                    ref.watch(appLocaleProvider).languageCode,
                    zh: '端到端 · 本地 · 警报级测试',
                    en: 'End-to-end · local · alert-level test',
                    ja: 'エンドツーエンド · ローカル · 警報レベルのテスト',
                  ),
                ),
                leading: const Icon(Icons.send_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openUsgsPushSheet(context),
              ),
              ListTile(
                title: Text(
                  tri3(
                    ref.watch(appLocaleProvider).languageCode,
                    zh: '推送历史',
                    en: 'Push history',
                    ja: 'プッシュ履歴',
                  ),
                ),
                subtitle: Text(
                  tri3(
                    ref.watch(appLocaleProvider).languageCode,
                    zh: '本机收到的地震 / 海啸通知记录',
                    en: 'Locally saved earthquake / tsunami alerts',
                    ja: '端末に保存された地震・津波通知の記録',
                  ),
                ),
                leading: const Icon(Icons.history),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const PushHistoryPage()),
                ),
              ),
            ],
          ),
          SettingsSectionHeader(
            text: pushFilterTitle(
              language: ref.watch(appLocaleProvider).languageCode,
            ),
          ),
          const _PushFilterSection(),
          SettingsSectionHeader(text: s.settingsLanguage),
          const _LanguageSelector(),
          SettingsSectionHeader(text: s.settingsAboutSection),
          const _UpdateCheckTile(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              s.settingsAboutBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.designSystem.colorTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 界面语言切换（简体中文 / English / 日本語）。
class _LanguageSelector extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLocaleProvider);
    final lang = current.languageCode;

    return M3ESegmentedColumn(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        ListTile(
          title: const Text('简体中文'),
          leading: const Icon(Icons.translate),
          trailing: lang == 'zh'
              ? const Icon(Icons.check_circle, color: Colors.teal)
              : null,
          onTap: () async => _apply(ref, const Locale('zh', 'CN')),
        ),
        ListTile(
          title: const Text('English'),
          leading: const Icon(Icons.language),
          trailing: lang == 'en'
              ? const Icon(Icons.check_circle, color: Colors.teal)
              : null,
          onTap: () async => _apply(ref, const Locale('en', 'US')),
        ),
        ListTile(
          title: const Text('日本語'),
          leading: const Icon(Icons.translate),
          trailing: lang == 'ja'
              ? const Icon(Icons.check_circle, color: Colors.teal)
              : null,
          onTap: () async => _apply(ref, const Locale('ja', 'JP')),
        ),
      ],
    );
  }

  Future<void> _apply(WidgetRef ref, Locale locale) async {
    await ref.read(appLocaleProvider.notifier).change(locale);
    // 渠道名/分组名跟随新语言重建（后台异步，失败不影响界面切换）。
    unawaited(ref.read(localNotificationRepositoryProvider).refreshLocalizedChannels());
  }
}

/// 推送条件（震级下限 / 海啸门槛 / 只推警报级）。改动即时落盘，直连链路下一次轮询就按新条件推。
class _PushFilterSection extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(pushFilterProvider);
    final notifier = ref.read(pushFilterProvider.notifier);
    final language = ref.watch(appLocaleProvider).languageCode;
    const magnitudes = <double>[2.5, 4.5, 6];

    Widget chips(List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(spacing: 6, runSpacing: 6, children: children),
    );

    Widget magnitudeChip(double value) => ChoiceChip(
      label: Text('M${value.toStringAsFixed(1)}+'),
      selected: filter.minMagnitude == value,
      onSelected: (_) async => notifier.change(
        filter.copyWith(minMagnitude: value),
      ),
    );

    Widget tsunamiChip(TsunamiLevel level) => ChoiceChip(
      label: Text(level.label(language)),
      selected: filter.tsunamiLevel == level,
      onSelected: (_) async => notifier.change(
        filter.copyWith(tsunamiLevel: level),
      ),
    );

    return M3ESegmentedColumn(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        ListTile(
          title: Text(pushFilterMinMagnitude(language: language)),
          subtitle: chips([
            for (final value in magnitudes) magnitudeChip(value),
          ]),
        ),
        ListTile(
          title: Text(pushFilterTsunami(language: language)),
          subtitle: chips([
            for (final level in TsunamiLevel.values) tsunamiChip(level),
          ]),
        ),
        SwitchListTile(
          title: Text(pushFilterAlertOnly(language: language)),
          subtitle: Text(pushFilterAlertOnlySubtitle(language: language)),
          value: filter.alertOnly,
          onChanged: (value) async =>
              notifier.change(filter.copyWith(alertOnly: value)),
        ),
        ListTile(
          dense: true,
          title: Text(
            pushFilterSummary(filter, language: language),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _AppVersionInformation extends HookConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'QuakePush ${packageInfo.version}',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: .bold,
              fontSize: 14,
            ),
          ),
          TextSpan(text: ' (Build ${packageInfo.buildNumber})\n'),
          TextSpan(text: ref.watch(appStringsProvider).settingsVersionTag),
        ],
        style: textTheme.bodyMedium?.copyWith(
          fontFamily: FontFamily.googleSansCode,
          letterSpacing: -0.05,
          fontSize: 12,
        ),
      ),
      textAlign: .center,
    );
  }
}

/// 从 GitHub Releases 检查新版本：只提示并跳转 Release 页，不在 App 内下载安装包。
class _UpdateCheckTile extends HookConsumerWidget {
  const _UpdateCheckTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLocaleProvider).languageCode;
    final checking = useState(false);

    Future<void> check() async {
      if (checking.value) {
        return;
      }
      final pkg = ref.read(packageInfoProvider);
      final localCode = int.tryParse(pkg.buildNumber) ?? 0;
      checking.value = true;
      final release = await GithubReleaseChecker.fetchLatest();
      if (!context.mounted) {
        return;
      }
      checking.value = false;

      if (release == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tri3(
                lang,
                zh: '检查失败，请稍后再试',
                en: 'Update check failed, try again later',
                ja: '確認に失敗しました。後でもう一度お試しください',
              ),
            ),
          ),
        );
        return;
      }
      if (release.versionCode > localCode) {
        await _UpdateCheckTile.showUpdateDialog(context, release, lang);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tri3(
                lang,
                zh: '已是最新版本',
                en: 'You are on the latest version',
                ja: '最新バージョンです',
              ),
            ),
          ),
        );
      }
    }

    return M3ESegmentedColumn(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        ListTile(
          leading: const Icon(Icons.system_update_outlined),
          title: Text(
            tri3(
              lang,
              zh: '检查更新',
              en: 'Check for updates',
              ja: 'アップデートを確認',
            ),
          ),
          subtitle: Text(
            checking.value
                ? tri3(
                    lang,
                    zh: '正在检查…',
                    en: 'Checking…',
                    ja: '確認中…',
                  )
                : tri3(
                    lang,
                    zh: '从 GitHub Releases 检查最新版本',
                    en: 'Check the latest release on GitHub',
                    ja: 'GitHub リリースから最新版を確認',
                  ),
          ),
          trailing: checking.value
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.open_in_new),
          onTap: checking.value ? null : check,
        ),
      ],
    );
  }

  /// 更新提示对话框：正文来自 Release 说明，按钮只负责打开浏览器到 Release 页。
  static Future<void> showUpdateDialog(
  BuildContext context,
  GithubReleaseInfo release,
  String lang,
) async {
  final body = release.body?.trim();
  final clipped = body == null || body.isEmpty
      ? null
      : body.length > 800
          ? '${body.substring(0, 800)}…'
          : body;
  final remoteName = release.name?.trim();
  final versionLabel =
      (remoteName == null || remoteName.isEmpty) ? release.tagName : remoteName;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        tri3(
          lang,
          zh: '发现新版本',
          en: 'Update available',
          ja: '新しいバージョン',
        ),
      ),
      content: SingleChildScrollView(
        child: Text(
          [
            versionLabel,
            if (clipped != null) clipped,
          ].join('\n\n'),
        ),
      ),
      actions: [
        M3ETextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            tri3(lang, zh: '关闭', en: 'Close', ja: '閉じる'),
          ),
        ),
        M3EFilledButton(
          onPressed: () => launchUrlString(
            release.htmlUrl,
            mode: LaunchMode.externalApplication,
          ),
          child: Text(
            tri3(
              lang,
              zh: '在浏览器打开',
              en: 'Open in browser',
              ja: 'ブラウザで開く',
            ),
          ),
        ),
      ],
    ),
  );
  }
}
