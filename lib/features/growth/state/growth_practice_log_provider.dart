import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/growth_config.dart';
import '../../../shared/testdata/growth_testdata.dart';
import '../domain/growth_repository.dart';
import '../domain/practice_day.dart';

// ══════════════════════════════════════════════════════════
// 練習日の記録（継続カレンダー用）プロバイダー
//
// ■ GrowthDataSourceMode / growthDataSourceModeProvider
//   growthPracticeDaysProvider・GrowthNotifier._loadAll の両方が参照する
//   「どのデータを表示・判定に使うか」の実効値。
//     real   … 実データ（Hive）のみ
//     test   … テストデータのみ
//     merged … テストデータ＋実データを日付ごとに合算して扱う
//              （例：テストデータで昨日までの20日分を作り、今日は実際に
//              アップロードして21日連続達成の挙動を見る、といった検証用）
//   GrowthConfig.useTestData（リリース時の初期値＝real）をアプリ起動時
//   の初期値として持ち、メンテナンス画面から検証用に切り替えられる。
//   ⚠ どこにも永続化しない（アプリ再起動で必ず real に戻る）。
//
//   習慣化サポート側は habitDataSourceModeProvider という別Providerで
//   独立して管理する（この enum 自体は両者で共用する）。
//
// ■ growthPracticeLogProvider
//   永続化された練習日の記録（実データ）。アップロードのたびに
//   GrowthNotifier が reload() を呼んで更新する。
//   画像を削除しても記録は残る（GrowthRecordとは独立して保持）。
//
// ■ growthPracticeDaysProvider
//   成長記録側の継続カレンダー（アップロード完了画面）用。
//   growthDataSourceModeProvider の値に応じて実データ／テストデータ／
//   両者を合算した記録を返す。
// ══════════════════════════════════════════════════════════
enum GrowthDataSourceMode { real, test, merged }

class GrowthDataSourceModeNotifier extends StateNotifier<GrowthDataSourceMode> {
  GrowthDataSourceModeNotifier()
      : super(GrowthConfig.useTestData
            ? GrowthDataSourceMode.test
            : GrowthDataSourceMode.real);

  void setValue(GrowthDataSourceMode value) => state = value;

  /// 【検証用】メンテナンス画面の「初期状態に戻す」から呼ばれる。
  void resetToDefault() => state = GrowthConfig.useTestData
      ? GrowthDataSourceMode.test
      : GrowthDataSourceMode.real;
}

final growthDataSourceModeProvider =
    StateNotifierProvider<GrowthDataSourceModeNotifier, GrowthDataSourceMode>(
        (ref) {
  return GrowthDataSourceModeNotifier();
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
  final mode = ref.watch(growthDataSourceModeProvider);
  final realDays = ref.watch(growthPracticeLogProvider);
  if (mode == GrowthDataSourceMode.real) return realDays;

  final testDays = PracticeDay.fromRecords(
      ref.watch(growthTestDataProvider).valueOrNull ?? const []);
  if (mode == GrowthDataSourceMode.test) return testDays;

  return PracticeDay.merge(testDays, realDays); // merged
});
