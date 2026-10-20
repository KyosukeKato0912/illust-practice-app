import '../../../core/constants/app_strings.dart';

// ══════════════════════════════════════════════════════════
// 復帰促進通知の空白期間の選択肢
// ══════════════════════════════════════════════════════════
enum HabitComebackPeriod {
  threeDays,
  oneWeek,
  oneMonth;

  /// 表示名
  String get label {
    switch (this) {
      case HabitComebackPeriod.threeDays: return AppStrings.habitComebackThreeDays;
      case HabitComebackPeriod.oneWeek:   return AppStrings.habitComebackOneWeek;
      case HabitComebackPeriod.oneMonth:  return AppStrings.habitComebackOneMonth;
    }
  }

  /// 実際の日数
  int get days {
    switch (this) {
      case HabitComebackPeriod.threeDays: return 3;
      case HabitComebackPeriod.oneWeek:   return 7;
      case HabitComebackPeriod.oneMonth:  return 30;
    }
  }

  /// SharedPreferences 保存用のキー文字列
  String get key {
    switch (this) {
      case HabitComebackPeriod.threeDays: return 'three_days';
      case HabitComebackPeriod.oneWeek:   return 'one_week';
      case HabitComebackPeriod.oneMonth:  return 'one_month';
    }
  }

  static HabitComebackPeriod fromKey(String key) {
    return HabitComebackPeriod.values.firstWhere(
      (e) => e.key == key,
      orElse: () => HabitComebackPeriod.oneWeek,
    );
  }
}

// ══════════════════════════════════════════════════════════
// 習慣化サポート 設定データクラス
// ══════════════════════════════════════════════════════════
class HabitSettings {
  /// true = 基本セット、false = 自由に設定
  final bool isPreset;

  /// 作業時間（分）
  final int timerMinutes;

  /// 休憩時間（分）
  final int breakMinutes;

  /// 作業開始促進通知を送るかどうか
  final bool reminderEnabled;

  /// 作業開始促進通知の時刻（時）
  final int reminderHour;

  /// 作業開始促進通知の時刻（分）
  final int reminderMinute;

  /// 復帰促進通知を送るかどうか
  final bool comebackEnabled;

  /// 復帰促進通知を出すまでの空白期間
  final HabitComebackPeriod comebackPeriod;

  const HabitSettings({
    required this.isPreset,
    required this.timerMinutes,
    required this.breakMinutes,
    required this.reminderEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.comebackEnabled,
    required this.comebackPeriod,
  });
}
