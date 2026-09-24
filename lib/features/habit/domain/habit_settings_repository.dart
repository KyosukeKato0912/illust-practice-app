import 'package:shared_preferences/shared_preferences.dart';
import 'habit_settings.dart';

// ══════════════════════════════════════════════════════════
// 習慣化サポート 設定の永続化リポジトリ
//
// state/ 層（HabitSettingsController）からのみ呼び出すこと。
// ui/ から直接importしない。
// ══════════════════════════════════════════════════════════
class HabitSettingsRepository {
  HabitSettingsRepository._();

  // ── SharedPreferences キー ─────────────────────────────
  static const _keyIsPreset          = 'habit_is_preset';
  static const _keyTimerMinutes      = 'habit_timer_minutes';
  static const _keyBreakMinutes      = 'habit_break_minutes';
  static const _keyReminderEnabled   = 'habit_reminder_enabled';
  static const _keyReminderHour      = 'habit_reminder_hour';
  static const _keyReminderMinute    = 'habit_reminder_minute';
  static const _keyComebackEnabled   = 'habit_comeback_enabled';
  static const _keyComebackPeriod    = 'habit_comeback_period';

  // ── デフォルト値（基本セット）──────────────────────────
  static const bool defaultIsPreset      = true;
  static const int  defaultTimerMinutes  = 25;
  static const int  defaultBreakMinutes  = 5;

  // ── 自由設定のデフォルト値 ────────────────────────────
  static const int defaultCustomTimerMinutes = 10;
  static const int defaultCustomBreakMinutes = 5;

  // ── 作業開始促進通知のデフォルト値 ────────────────────
  static const bool defaultReminderEnabled = false;
  static const int  defaultReminderHour    = 12;
  static const int  defaultReminderMinute  = 0;

  // ── 復帰促進通知のデフォルト値 ────────────────────────
  static const bool defaultComebackEnabled = false;
  static const HabitComebackPeriod defaultComebackPeriod =
      HabitComebackPeriod.oneWeek;

  /// 設定を保存する
  static Future<void> save({
    required bool isPreset,
    required int timerMinutes,
    required int breakMinutes,
    required bool reminderEnabled,
    required int reminderHour,
    required int reminderMinute,
    required bool comebackEnabled,
    required HabitComebackPeriod comebackPeriod,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPreset,        isPreset);
    await prefs.setInt(_keyTimerMinutes,     timerMinutes);
    await prefs.setInt(_keyBreakMinutes,     breakMinutes);
    await prefs.setBool(_keyReminderEnabled, reminderEnabled);
    await prefs.setInt(_keyReminderHour,     reminderHour);
    await prefs.setInt(_keyReminderMinute,   reminderMinute);
    await prefs.setBool(_keyComebackEnabled, comebackEnabled);
    await prefs.setString(_keyComebackPeriod, comebackPeriod.key);
  }

  /// 設定を読み込む。未保存の場合は null を返す。
  static Future<HabitSettings?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_keyIsPreset)) return null;
    return HabitSettings(
      isPreset:        prefs.getBool(_keyIsPreset)        ?? defaultIsPreset,
      timerMinutes:    prefs.getInt(_keyTimerMinutes)     ?? defaultTimerMinutes,
      breakMinutes:    prefs.getInt(_keyBreakMinutes)     ?? defaultBreakMinutes,
      reminderEnabled: prefs.getBool(_keyReminderEnabled) ?? defaultReminderEnabled,
      reminderHour:    prefs.getInt(_keyReminderHour)     ?? defaultReminderHour,
      reminderMinute:  prefs.getInt(_keyReminderMinute)   ?? defaultReminderMinute,
      comebackEnabled: prefs.getBool(_keyComebackEnabled) ?? defaultComebackEnabled,
      comebackPeriod:  HabitComebackPeriod.fromKey(
          prefs.getString(_keyComebackPeriod) ?? defaultComebackPeriod.key),
    );
  }

  /// 設定を削除（デフォルトにリセット）
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsPreset);
    await prefs.remove(_keyTimerMinutes);
    await prefs.remove(_keyBreakMinutes);
    await prefs.remove(_keyReminderEnabled);
    await prefs.remove(_keyReminderHour);
    await prefs.remove(_keyReminderMinute);
    await prefs.remove(_keyComebackEnabled);
    await prefs.remove(_keyComebackPeriod);
  }
}
