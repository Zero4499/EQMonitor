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
}

/// 推送条件：震级下限、海啸门槛、是否只推警报级。
class PushFilter {
  const PushFilter({
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

  /// 海啸公报是否该推送。按标题判断级别。
  bool allowsTsunami(String title) {
    final t = title.toLowerCase();
    final isWarning = t.contains('warning') || t.contains('threat');
    final isAdvisory = t.contains('watch') || t.contains('advisory');
    if (isWarning) {
      return true;
    }
    if (alertOnly) {
      return false;
    }
    return switch (tsunamiLevel) {
      .all => true,
      .advisory => isAdvisory,
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

/// i18n 里没定义的推送条件文案，直接放这里（中英双语）。
String pushFilterTitle({required bool isEnglish}) =>
    isEnglish ? 'Push conditions' : '推送条件';

String pushFilterMinMagnitude({required bool isEnglish}) =>
    isEnglish ? 'Minimum magnitude' : '最小震级';

String pushFilterTsunami({required bool isEnglish}) =>
    isEnglish ? 'Tsunami level' : '海啸级别';

String pushFilterAlertOnly({required bool isEnglish}) =>
    isEnglish ? 'Alert grade only' : '只推警报级';

String pushFilterAlertOnlySubtitle({required bool isEnglish}) => isEnglish
    ? 'Only M7+ / PAGER red / tsunami warning'
    : '只推 M7+ / PAGER red / 海啸警报';

String pushFilterSummary(PushFilter filter, {required bool isEnglish}) =>
    isEnglish
        ? 'M${filter.minMagnitude.toStringAsFixed(1)}+ · ${filter.tsunamiLevel.labelEn}'
        : 'M${filter.minMagnitude.toStringAsFixed(1)}+ · ${filter.tsunamiLevel.labelZh}';
