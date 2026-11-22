import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/gen/assets.gen.dart';
import 'package:eqmonitor/core/gen/fonts.gen.dart';
import 'package:eqmonitor/core/filter/push_filter.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/i18n/tri.dart';
import 'package:eqmonitor/core/notification/notification_permissions.dart';
import 'package:eqmonitor/core/provider/package_info.dart';
import 'package:eqmonitor/core/router/router.dart';
import 'package:eqmonitor/feature/settings/component/settings_section_header.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

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
                title: Text(s.settingsNotificationTile),
                subtitle: Text(s.settingsNotificationSubtitle),
                leading: const Icon(Icons.notifications_outlined),
                onTap: () async =>
                    const NotificationSettingsRoute().push<void>(context),
              ),
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
                    zh: '通知 · 全屏 intent · 精确闹钟 · 勿扰访问 · 电池白名单',
                    en: 'Notifications · full-screen intent · exact alarms · DND · battery whitelist',
                    ja: '通知 · 全画面 intent · 正確なアラーム · サイレントモード · バッテリー最適化除外',
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
                    zh: '勿扰模式例外',
                    en: 'Do Not Disturb exception',
                    ja: 'サイレントモードの例外',
                  ),
                ),
                subtitle: Text(
                  tri3(
                    ref.watch(appLocaleProvider).languageCode,
                    zh: '把本应用加进系统的勿扰白名单，否则勿扰模式下通知不响',
                    en: 'Whitelist this app in system Do Not Disturb settings',
                    ja: 'サイレントモード中も鳴らすため、システム側で許可します',
                  ),
                ),
                leading: const Icon(Icons.do_not_disturb_off_outlined),
                onTap: () async {
                  final granted = await NotificationPermissions.requestDndAccess();
                  if (!context.mounted) {
                    return;
                  }
                  final lang = ref.watch(appLocaleProvider).languageCode;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tri3(
                          lang,
                          zh: granted == true
                              ? '已加入勿扰例外，通知在静音模式下也会响'
                              : '请在打开的系统页面里把本应用打开为允许例外',
                          en: granted == true
                              ? 'Allowed to interrupt Do Not Disturb'
                              : 'Please allow this app in the system settings that just opened',
                          ja: granted == true
                              ? 'サイレントモード中も通知が鳴ります'
                              : '開いたシステム設定でこのアプリを許可してください',
                        ),
                      ),
                    ),
                  );
                },
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
