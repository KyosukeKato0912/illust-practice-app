import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/growth_config.dart';
import '../../../shared/testdata/growth_testdata.dart';
import '../domain/growth_repository.dart';
import '../domain/practice_day.dart';

// ══════════════════════════════════════════════════════════
// 練習日の記録（継続カレンダー用）プロバイダー
//
// ■ growthUseTestDataProvider
//   growthPracticeDaysProvider・GrowthNotifier._loadAll の両方が参照する
//   「テストデータ表示中かどうか」の実効値。
//   GrowthConfig.useTestData（リリース時の初期値＝false）をアプリ起動時
//   の初期値として持ち、メンテナンス画面から検証用に上書きできる。
//   ⚠ どこにも永続化しない（アプリ再起動で必ず false に戻る）。
//
// ■ growthPracticeLogProvider
//   永続化された練習日の記録（実データ）。アップロードのたびに
//   GrowthNotifier が reload() を呼んで更新する。
//   画像を削除しても記録は残る（GrowthRecordとは独立して保持）。
//
// ■ growthPracticeDaysProvider
//   成長記録側の継続カレンダー（アップロード完了画面）用。
//   growthUseTestDataProvider が true の間はテストデータ由来の記録、
//   false の間は実データを返す。
//   （習慣化サポート側は habitUseTestDataProvider に従う別Provider
//     habitPracticeDaysProvider を使う）
// ══════════════════════════════════════════════════════════
class GrowthUseTestDataNotifier extends StateNotifier<bool> {
  GrowthUseTestDataNotifier() : super(GrowthConfig.useTestData);

  void setValue(bool value) => state = value;

  /// 【検証用】メンテナンス画面の「初期状態に戻す」から呼ばれる。
  void resetToDefault() => state = GrowthConfig.useTestData;
}

final growthUseTestDataProvider =
    StateNotifierProvider<GrowthUseTestDataNotifier, bool>((ref) {
  return GrowthUseTestDataNotifier();
});

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
  if (ref.watch(growthUseTestDataProvider)) {
    return PracticeDay.fromRecords(
        ref.watch(growthTestDataProvider).valueOrNull ?? const []);
  }
  return ref.watch(growthPracticeLogProvider);
});
