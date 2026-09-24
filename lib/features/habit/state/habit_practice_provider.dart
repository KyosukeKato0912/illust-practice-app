import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/habit_config.dart';
import '../../../shared/testdata/growth_testdata.dart';
import '../../growth/domain/practice_day.dart';
import '../../growth/state/growth_practice_log_provider.dart';
import 'habit_settings_controller.dart';

// ══════════════════════════════════════════════════════════
// 習慣化サポート 練習記録プロバイダー（state/ 層）
//
// ■ habitPracticeDaysProvider
//   継続カレンダーの元データ（練習日の記録）。HabitConfig.useTestData に
//   応じてテストデータ（growthTestDataProvider）／実データ
//   （growthPracticeLogProvider）を切り替える。
//   実データは成長記録の画像を削除しても残る。継続カレンダー
//   （habit_main_screen.dart）と復帰促進通知の最終練習日が必ず同じ
//   元データを参照するよう、この分岐はここだけに持つ。
//
// ■ habitLastPracticeDateProvider
//   元データ中で最も新しい記録日（日付のみ）。記録が無ければ null。
//   値が変わったときだけ通知される（同日の追加アップロード等では通知されない）。
//
// ■ habitComebackSyncProvider
//   最終練習日の変化を監視し、復帰促進通知のスケジュールを更新する。
//   アプリ全体で常駐させるため app.dart から watch する。
//   （設定の保存・リセット時の更新は HabitSettingsController 側で行う）
// ══════════════════════════════════════════════════════════

/// 継続カレンダーの元データ（フラグで実データ／テストデータを切替）
final habitPracticeDaysProvider = Provider<List<PracticeDay>>((ref) {
  if (HabitConfig.useTestData) {
    return PracticeDay.fromRecords(
        ref.watch(growthTestDataProvider).valueOrNull ?? const []);
  }
  return ref.watch(growthPracticeLogProvider);
});

/// 最終練習日（＝アップロードされた日のうち最新のもの）。記録なしは null。
final habitLastPracticeDateProvider = Provider<DateTime?>((ref) {
  final days = ref.watch(habitPracticeDaysProvider);
  DateTime? latest;
  for (final day in days) {
    final d = DateTime(day.date.year, day.date.month, day.date.day);
    if (latest == null || d.isAfter(latest)) latest = d;
  }
  return latest;
});

/// 最終練習日が変わったら、復帰促進通知のスケジュールを更新する
final habitComebackSyncProvider = Provider<void>((ref) {
  ref.listen<DateTime?>(habitLastPracticeDateProvider, (previous, next) {
    HabitSettingsController.syncComebackWithSavedSettings(next);
  });
});
