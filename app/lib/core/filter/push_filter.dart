import 'package:eqmonitor/core/feed/quake_feed.dart';
import 'package:eqmonitor/core/i18n/tri.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 海啸推送门槛。
enum TsunamiLevel {
  /// 全部公报都推
  all,

  /// 关注级以上（watch / advisory）
  advisory,

  /// 只要警报级（warning / threat）
  warning;

  String get labelZh => switch (this) {
    .all => '全部公报',
    .advisory => '关注级以上',
    .warning => '只要警报',
  };

  String get labelEn => switch (this) {
    .all => 'All bulletins',
    .advisory => 'Advisory and above',
    .warning => 'Warnings only',
  };

  String get labelJa => switch (this) {
    .all => 'すべての情報',
    .advisory => '注意報以上',
    .warning => '警報のみ',
  };

  String label(String language) => switch (language) {
    'en' => labelEn,
    'ja' => labelJa,
    _ => labelZh,
  };
}

/// 推送条件：震级下限、海啸门槛、是否只推警报级。
class PushFilter {
  const new({
    this.minMagnitude = 4.5,
    this.tsunamiLevel = TsunamiLevel.warning,
    this.alertOnly = false,
  });

  final double minMagnitude;
  final TsunamiLevel tsunamiLevel;
  final bool alertOnly;

  PushFilter copyWith({
    double? minMagnitude,
    TsunamiLevel? tsunamiLevel,
    bool? alertOnly,
  }) => PushFilter(
    minMagnitude: minMagnitude ?? this.minMagnitude,
    tsunamiLevel: tsunamiLevel ?? this.tsunamiLevel,
    alertOnly: alertOnly ?? this.alertOnly,
  );

  /// 地震是否该推送。[major] 为警报级（M7+ / PAGER red）时无视门槛。
  bool allowsQuake({double? magnitude, bool major = false}) {
    if (major) {
      return true;
    }
    if (alertOnly) {
      return false;
    }
    return magnitude != null && magnitude >= minMagnitude;
  }

  /// 海啸公报是否该推送。按解析出的分级判断。
  bool allowsTsunami(TsunamiCategory category) {
    if (category == .warning) {
      return true;
    }
    if (alertOnly) {
      return false;
    }
    return switch (tsunamiLevel) {
      .all => true,
      .advisory => category == .advisory,
      .warning => false,
    };
  }
}

/// 推送条件的持久化（沿用 AppLocaleSetting 的做法：静态值 + 启动时 load）。
class PushFilterSetting {
  const PushFilterSetting._();

  static const prefsKey = 'push_filter_v1';

  static PushFilter value = const PushFilter();

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final min = prefs.getDouble('${prefsKey}_min_mag');
    final level = prefs.getString('${prefsKey}_tsunami');
    final alertOnly = prefs.getBool('${prefsKey}_alert_only');
    value = PushFilter(
      minMagnitude: min ?? 4.5,
      tsunamiLevel: switch (level) {
        'all' => TsunamiLevel.all,
        'advisory' => TsunamiLevel.advisory,
        _ => TsunamiLevel.warning,
      },
      alertOnly: alertOnly ?? false,
    );
  }

  static Future<void> save(PushFilter filter) async {
    value = filter;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${prefsKey}_min_mag', filter.minMagnitude);
    await prefs.setString(
      '${prefsKey}_tsunami',
      switch (filter.tsunamiLevel) {
        TsunamiLevel.all => 'all',
        TsunamiLevel.advisory => 'advisory',
        TsunamiLevel.warning => 'warning',
      },
    );
    await prefs.setBool('${prefsKey}_alert_only', filter.alertOnly);
  }
}

final pushFilterProvider = NotifierProvider<PushFilterNotifier, PushFilter>(
  PushFilterNotifier.new,
);

class PushFilterNotifier extends Notifier<PushFilter> {
  @override
  PushFilter build() => PushFilterSetting.value;

  Future<void> change(PushFilter filter) async {
    await PushFilterSetting.save(filter);
    state = filter;
  }
}

/// i18n 里没定义的推送条件文案，直接放这里（中英日）。
String pushFilterTitle({required String language}) => tri3(
  language,
  zh: '推送条件',
  en: 'Push conditions',
  ja: 'プッシュ条件',
);

String pushFilterMinMagnitude({required String language}) => tri3(
  language,
  zh: '最小震级',
  en: 'Minimum magnitude',
  ja: '最小マグニチュード',
);

String pushFilterTsunami({required String language}) => tri3(
  language,
  zh: '海啸级别',
  en: 'Tsunami level',
  ja: '津波レベル',
);

String pushFilterAlertOnly({required String language}) => tri3(
  language,
  zh: '只推警报级',
  en: 'Alert grade only',
  ja: 'アラート級のみ',
);

String pushFilterAlertOnlySubtitle({required String language}) => tri3(
  language,
  zh: '只推 M7+ / PAGER red / 海啸警报',
  en: 'Only M7+ / PAGER red / tsunami warning',
  ja: 'M7+ / PAGER red / 津波警報のみ',
);

String pushFilterSummary(PushFilter filter, {required String language}) =>
    'M${filter.minMagnitude.toStringAsFixed(1)}+ · '
    '${filter.tsunamiLevel.label(language)}';
