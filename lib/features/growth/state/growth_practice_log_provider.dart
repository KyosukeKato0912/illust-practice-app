import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/growth_config.dart';
import '../../../shared/testdata/growth_testdata.dart';
import '../domain/growth_repository.dart';
import '../domain/practice_day.dart';

// ══════════════════════════════════════════════════════════
// 練習日の記録（継続カレンダー用）プロバイダー
//
// ■ growthPracticeLogProvider
//   永続化された練習日の記録（実データ）。アップロードのたびに
//   GrowthNotifier が reload() を呼んで更新する。
//   画像を削除しても記録は残る（GrowthRecordとは独立して保持）。
//
// ■ growthPracticeDaysProvider
//   成長記録側の継続カレンダー（アップロード完了画面）用。
//   GrowthConfig.useTestData が true の間はテストデータ由来の記録、
//   false の間は実データを返す。
//   （習慣化サポート側は HabitConfig.useTestData に従う別Provider
//     habitPracticeDaysProvider を使う）
// ══════════════════════════════════════════════════════════
class GrowthPracticeLogNotifier extends StateNotifier<List<PracticeDay>> {
  final GrowthRepository _repository;

  GrowthPracticeLogNotifier({GrowthRepository? repository})
      : _repository = repository ?? GrowthRepository(),
        super(const []) {
    reload();
  }

  Future<void> reload() async {
    state = await _repository.getPracticeDays();
  }
}

final growthPracticeLogProvider =
    StateNotifierProvider<GrowthPracticeLogNotifier, List<PracticeDay>>((ref) {
  return GrowthPracticeLogNotifier();
});

final growthPracticeDaysProvider = Provider<List<PracticeDay>>((ref) {
  if (GrowthConfig.useTestData) {
    return PracticeDay.fromRecords(
        ref.watch(growthTestDataProvider).valueOrNull ?? const []);
  }
  return ref.watch(growthPracticeLogProvider);
});
