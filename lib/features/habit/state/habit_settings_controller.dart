import 'package:flutter/foundation.dart' show debugPrint;
import '../../../core/services/notification_service.dart';
import '../domain/habit_settings.dart';
import '../domain/habit_settings_repository.dart';

// ══════════════════════════════════════════════════════════
// 習慣化サポート 設定 コントローラー（state/ 層）
//
// ui/ → state/ のみ参照というレイヤー依存ルールに沿って、
// HabitSettingsRepository（domain/）とNotificationService（data/services/相当）
// への直接アクセスをこの薄いラッパーに集約する。
// 設定の保存・リセットに伴う通知スケジュールの更新もここで完結させ、
// ui/ 側は保存/リセットを呼ぶだけでよい形にする。
//
// ⚠ Riverpodは使わない：
//   設定値の読み書きは設定画面内で完結し、メリハリタイマー
//   （HabitTimerNotifier）のように画面をまたいで状態を維持し
//   続ける必要がない。そのため habit_timer_notifier.dart と
//   異なりStateNotifier化はせず、Repositoryの呼び出し口を
//   1枚挟むだけのシンプルなControllerとして提供する。
//   （Riverpod化 vs 非Riverpodの使い分け基準は
//     構成設計④命名規則・設計指針を参照）
// ══════════════════════════════════════════════════════════
class HabitSettingsController {
  HabitSettingsController._();

  // ── デフォルト値（UI初期表示用にそのまま転送）────────────
  static const bool defaultIsPreset = HabitSettingsRepository.defaultIsPreset;
  static const int defaultTimerMinutes =
      HabitSettingsRepository.defaultTimerMinutes;
  static const int defaultBreakMinutes =
      HabitSettingsRepository.defaultBreakMinutes;
  static const int defaultCustomTimerMinutes =
      HabitSettingsRepository.defaultCustomTimerMinutes;
  static const int defaultCustomBreakMinutes =
      HabitSettingsRepository.defaultCustomBreakMinutes;
  static const bool defaultReminderEnabled =
      HabitSettingsRepository.defaultReminderEnabled;
  static const int defaultReminderHour =
      HabitSettingsRepository.defaultReminderHour;
  static const int defaultReminderMinute =
      HabitSettingsRepository.defaultReminderMinute;
  static const bool defaultComebackEnabled =
      HabitSettingsRepository.defaultComebackEnabled;
  static const HabitComebackPeriod defaultComebackPeriod =
      HabitSettingsRepository.defaultComebackPeriod;

  /// 保存済み設定を読み込む
  static Future<HabitSettings?> load() => HabitSettingsRepository.load();

  /// 設定を保存し、通知スケジュールも合わせて更新する。
  /// [lastPracticeDate] は復帰促進通知の起点（継続カレンダーの最終記録日。
  /// 記録なしは null）。
  static Future<void> save({
    required bool isPreset,
    required int timerMinutes,
    required int breakMinutes,
    required bool reminderEnabled,
    required int reminderHour,
    required int reminderMinute,
    required bool comebackEnabled,
    required HabitComebackPeriod comebackPeriod,
    DateTime? lastPracticeDate,
  }) async {
    await HabitSettingsRepository.save(
      isPreset: isPreset,
      timerMinutes: timerMinutes,
      breakMinutes: breakMinutes,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      comebackEnabled: comebackEnabled,
      comebackPeriod: comebackPeriod,
    );
    await _syncNotifications(
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      comebackEnabled: comebackEnabled,
      comebackPeriod: comebackPeriod,
      lastPracticeDate: lastPracticeDate,
    );
  }

  /// 設定をクリアし（デフォルトに戻す）、通知スケジュールもデフォルトで更新する
  static Future<void> clear({DateTime? lastPracticeDate}) async {
    await HabitSettingsRepository.clear();
    await _syncNotifications(
      reminderEnabled: defaultReminderEnabled,
      reminderHour: defaultReminderHour,
      reminderMinute: defaultReminderMinute,
      comebackEnabled: defaultComebackEnabled,
      comebackPeriod: defaultComebackPeriod,
      lastPracticeDate: lastPracticeDate,
    );
  }

  /// 保存済み設定（未保存ならデフォルト）で復帰促進通知を更新する。
  /// 最終練習日の変化時に habitComebackSyncProvider から呼ばれる。
  static Future<void> syncComebackWithSavedSettings(
      DateTime? lastPracticeDate) async {
    try {
      final saved = await load();
      await _syncComeback(
        enabled: saved?.comebackEnabled ?? defaultComebackEnabled,
        period: saved?.comebackPeriod ?? defaultComebackPeriod,
        lastPracticeDate: lastPracticeDate,
      );
    } catch (e) {
      debugPrint('[HabitSettingsController] comeback sync failed: $e');
    }
  }

  // ── 正確なアラーム権限（ui/ から NotificationService を直接触らせない窓口）──
  /// 正確なアラーム（時刻ちょうどの通知）が許可されているか
  static Future<bool> isExactAlarmPermissionGranted() =>
      NotificationService.canScheduleExactAlarms();

  /// 設定画面（アラームとリマインダー）を開いて許可を求める。
  /// 戻ったあとの許可状態を返す。
  static Future<bool> requestExactAlarmPermission() =>
      NotificationService.requestExactAlarmPermission();

  // ── 通知スケジュールの同期 ────────────────────────────
  static Future<void> _syncNotifications({
    required bool reminderEnabled,
    required int reminderHour,
    required int reminderMinute,
    required bool comebackEnabled,
    required HabitComebackPeriod comebackPeriod,
    DateTime? lastPracticeDate,
  }) async {
    // 作業開始促進通知スケジュールを更新
    if (reminderEnabled) {
      await NotificationService.scheduleReminder(
          hour: reminderHour, minute: reminderMinute);
    } else {
      await NotificationService.cancelReminder();
    }
    // 復帰促進通知スケジュールを更新
    await _syncComeback(
      enabled: comebackEnabled,
      period: comebackPeriod,
      lastPracticeDate: lastPracticeDate,
    );
  }

  // ── 復帰促進通知の同期 ────────────────────────────────
  // ON かつ最終練習日がある場合のみ「最終練習日＋空白期間」で登録し、
  // OFF または記録なしの場合は解除する。
  static Future<void> _syncComeback({
    required bool enabled,
    required HabitComebackPeriod period,
    required DateTime? lastPracticeDate,
  }) async {
    if (!enabled || lastPracticeDate == null) {
      await NotificationService.cancelComeback();
      return;
    }
    await NotificationService.scheduleComebackIfNeeded(
      lastPracticeDate: lastPracticeDate,
      thresholdDays: period.days,
    );
  }
}
