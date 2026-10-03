import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/habit_config.dart';
import '../../../shared/testdata/growth_testdata.dart';
import '../../growth/domain/practice_day.dart';
import '../../growth/state/growth_practice_log_provider.dart';
import 'habit_settings_controller.dart';

// ══════════════════════════════════════════════════════════
// 習慣化サポート 練習記録プロバイダー（state/ 層）
//
// ■ habitUseTestDataProvider
//   habitPracticeDaysProviderが参照する「テストデータ表示中かどうか」の
//   実効値。HabitConfig.useTestData（リリース時の初期値＝false）を
//   アプリ起動時の初期値として持ち、メンテナンス画面から検証用に
//   上書きできる。
//   ⚠ どこにも永続化しない（アプリ再起動で必ず false に戻る）。
//
// ■ habitShowDebugDataCountProvider
//   継続カレンダー下の登録件数表示（_DebugCountChip）を出すかどうかの
//   実効値。HabitConfig.showDebugDataCount（リリース時の初期値＝false）
//   をアプリ起動時の初期値として持ち、メンテナンス画面から検証用に
//   切り替えられる。
//   ⚠ どこにも永続化しない（アプリ再起動で必ず false に戻る）。
//
// ■ habitPracticeDaysProvider
//   継続カレンダーの元データ（練習日の記録）。habitUseTestDataProvider に
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
class HabitUseTestDataNotifier extends StateNotifier<bool> {
  HabitUseTestDataNotifier() : super(HabitConfig.useTestData);

  void setValue(bool value) => state = value;

  /// 【検証用】メンテナンス画面の「初期状態に戻す」から呼ばれる。
  void resetToDefault() => state = HabitConfig.useTestData;
}

final habitUseTestDataProvider =
    StateNotifierProvider<HabitUseTestDataNotifier, bool>((ref) {
  return HabitUseTestDataNotifier();
});

class HabitShowDebugDataCountNotifier extends StateNotifier<bool> {
  HabitShowDebugDataCountNotifier() : super(HabitConfig.showDebugDataCount);

  void setValue(bool value) => state = value;

  /// 【検証用】メンテナンス画面の「初期状態に戻す」から呼ばれる。
  void resetToDefault() => state = HabitConfig.showDebugDataCount;
}

final habitShowDebugDataCountProvider =
    StateNotifierProvider<HabitShowDebugDataCountNotifier, bool>((ref) {
  return HabitShowDebugDataCountNotifier();
});

/// 継続カレンダーの元データ（フラグで実データ／テストデータを切替）
final habitPracticeDaysProvider = Provider<List<PracticeDay>>((ref) {
  if (ref.watch(habitUseTestDataProvider)) {
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
