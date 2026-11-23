import 'package:app_settings/app_settings.dart';
import 'package:eqmonitor/core/designsystem/design_system_build_context_x.dart';
import 'package:eqmonitor/core/fcm/channels.dart';
import 'package:eqmonitor/core/i18n/app_strings.dart';
import 'package:eqmonitor/core/i18n/tri.dart';
import 'package:eqmonitor/core/ntfy/ntfy_push_service.dart';
import 'package:eqmonitor/core/notification/notification_permissions.dart';
import 'package:eqmonitor/feature/settings/component/settings_section_header.dart';
import 'package:eqmonitor/feature/settings/features/notification_settings/ui/component/usgs_push_tile.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

class NotificationSettingsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(AppLocaleSetting.value).notificationPageTitle)),
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
        const _ChannelList(),
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

/// 分级渠道列表：每条可试听提示音 / 振动 / 灯色，或跳到系统渠道设置。
class _ChannelList extends ConsumerWidget {
  const _ChannelList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLocaleProvider).languageCode;
    final channels = buildNotificationChannels()
        .where((channel) => channel.id != 'service_fallback_v3')
        .toList();
    return M3ESegmentedColumn(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final channel in channels)
          ListTile(
            title: Text(channel.name),
            subtitle: Text(channel.description ?? ''),
            leading: IconButton(
              tooltip: tri3(language, zh: '试听', en: 'Test', ja: 'テスト'),
              icon: const Icon(Icons.surround_sound_outlined),
              onPressed: () => ref
                  .read(ntfyPushServiceProvider)
                  .showChannelTest(
                    channelId: channel.id,
                    alert: channel.importance == Importance.max,
                  ),
            ),
            trailing: IconButton(
              tooltip: tri3(
                language,
                zh: '渠道设置',
                en: 'Channel settings',
                ja: 'チャンネル設定',
              ),
              icon: const Icon(Icons.open_in_new),
              onPressed: () =>
                  NotificationPermissions.openChannelDetailSettings(channel.id),
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
    return ListTile(
      title: Text(AppStrings.of(AppLocaleSetting.value).systemChannelTile),
      subtitle: Text(AppStrings.of(AppLocaleSetting.value).systemChannelSubtitle),
      leading: const Icon(Icons.tune_outlined),
      trailing: const Icon(Icons.open_in_new),
      onTap: () async =>
          AppSettings.openAppSettings(type: AppSettingsType.notification),
    );
  }
}
