import 'package:app_settings/app_settings.dart';
import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/feature/settings/component/settings_section_header.dart';
import 'package:eqmonitor/feature/settings/features/notification_settings/ui/component/usgs_push_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class NotificationSettingsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(AppLocaleSetting.value);
    return Scaffold(
      appBar: AppBar(title: Text(s.notificationPageTitle)),
      body: const _Body(),
    );
  }
}

class _Body extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        SettingsSectionHeader(text: s.pushChannelSection),
        const UsgsPushTile(),
        SettingsSectionHeader(text: s.systemSection),
        const _AndroidNotificationSettingsTile(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            s.limitsBody,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.designSystem.colorTheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _AndroidNotificationSettingsTile extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final s = AppStrings.of(AppLocaleSetting.value);
    return ListTile(
      title: Text(s.systemChannelTile),
      subtitle: Text(s.systemChannelSubtitle),
      leading: const Icon(Icons.tune_outlined),
      trailing: const Icon(Icons.open_in_new),
      onTap: () async =>
          AppSettings.openAppSettings(type: AppSettingsType.notification),
    );
  }
}
