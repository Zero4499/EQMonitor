import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/gen/assets.gen.dart';
import 'package:eqmonitor/core/gen/fonts.gen.dart';
import 'package:eqmonitor/core/filter/push_filter.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
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
    final isEnglish = ref.watch(appLocaleProvider).languageCode == 'en';

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
                  isEnglish
                      ? 'Grant all notification permissions'
                      : '一键申请全部通知权限',
                ),
                subtitle: Text(
                  isEnglish
                      ? 'Notifications · full-screen intent · exact alarms · DND · battery whitelist'
                      : '通知 · 全屏 intent · 精确闹钟 · 勿扰访问 · 电池白名单',
                ),
                leading: const Icon(Icons.verified_user_outlined),
                onTap: () async =>
                    NotificationPermissions.requestAllIfNeeded(force: true),
              ),
            ],
          ),
          SettingsSectionHeader(
            text: pushFilterTitle(isEnglish: isEnglish),
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

/// 界面语言切换（简体中文 / English）。
class _LanguageSelector extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLocaleProvider);
    final isEnglish = current.languageCode == 'en';

    return M3ESegmentedColumn(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        ListTile(
          title: const Text('简体中文'),
          leading: const Icon(Icons.translate),
          trailing: !isEnglish
              ? const Icon(Icons.check_circle, color: Colors.teal)
              : null,
          onTap: () async => _apply(ref, const Locale('zh', 'CN')),
        ),
        ListTile(
          title: const Text('English'),
          leading: const Icon(Icons.language),
          trailing: isEnglish
              ? const Icon(Icons.check_circle, color: Colors.teal)
              : null,
          onTap: () async => _apply(ref, const Locale('en', 'US')),
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
    final isEnglish = ref.watch(appLocaleProvider).languageCode == 'en';
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
      label: Text(isEnglish ? level.labelEn : level.labelZh),
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
          title: Text(pushFilterMinMagnitude(isEnglish: isEnglish)),
          subtitle: chips([
            for (final value in magnitudes) magnitudeChip(value),
          ]),
        ),
        ListTile(
          title: Text(pushFilterTsunami(isEnglish: isEnglish)),
          subtitle: chips([
            for (final level in TsunamiLevel.values) tsunamiChip(level),
          ]),
        ),
        SwitchListTile(
          title: Text(pushFilterAlertOnly(isEnglish: isEnglish)),
          subtitle: Text(pushFilterAlertOnlySubtitle(isEnglish: isEnglish)),
          value: filter.alertOnly,
          onChanged: (value) async =>
              notifier.change(filter.copyWith(alertOnly: value)),
        ),
        ListTile(
          dense: true,
          title: Text(
            pushFilterSummary(filter, isEnglish: isEnglish),
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
