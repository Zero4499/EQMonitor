import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/gen/assets.gen.dart';
import 'package:eqmonitor/core/gen/fonts.gen.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
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
            ],
          ),
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
