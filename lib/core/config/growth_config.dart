import '../constants/app_values.dart';

// ══════════════════════════════════════════════════════════
// 成長記録 コンフィグ
//
// 成長記録の保持上限枚数など、ステータス管理に関わる数値は
// ここに一元管理する。変更する際はこのファイルの値のみ書き換えればよい。
//
// ※ 保持上限到達フラグのON/OFF切り替え（検証用）は
//   features/maintenance/ui/maintenance_screen.dart に移設した。
// ══════════════════════════════════════════════════════════
abstract class GrowthConfig {
  /// 保持できる成長記録の最大枚数（リリース時の初期値）。
  /// これを超えてアップロードされた場合、最も古いものから自動削除する。
  ///
  /// ⚠ 実際に判定・削除処理で使われる値は、この定数そのものではなく
  ///   [growthMaxRecordCountProvider]（features/growth/state/growth_provider.dart）
  ///   経由の値。メンテナンス画面から検証用に上書きできるようにするため、
  ///   このProviderは初期値としてこの定数を使い、アプリ起動のたびに
  ///   必ずこの定数の値へ戻る。
  static const int maxRecordCount = 300;

  /// 検証用：成長記録の一覧を実データ（Hive）の代わりに
  /// shared/testdata/growth_testdata.dart のテストデータで表示するか
  /// どうか（リリース時の初期値）。
  ///
  /// ⚠ 実際に使われる値は、この定数そのものではなく
  ///   [growthDataSourceModeProvider]
  ///   （features/growth/state/growth_practice_log_provider.dart）経由の
  ///   値（real/test/merged の3値）。メンテナンス画面から検証用に
  ///   切り替えられるようにするため、このProviderは初期値として
  ///   この定数（false→real）を使い、アプリ起動のたびに必ずその値へ戻る。
  /// habit_main_screen.dart 側の表示切替は HabitConfig.useTestData
  /// （実際には habitDataSourceModeProvider）で独立して管理しており、
  /// 本フラグとは連動しない。
  static const bool useTestData = false;

  /// 継続日数のマイルストーン特別メッセージを表示する連続日数。
  /// アップロード完了画面で、今日を含めた連続アップロード日数が
  /// ちょうどこの値に達した回のみ表示する。
  static const int streakMilestoneDays = AppValues.streakTargetDays;

  /// SNS共有（共有シート）に一度に渡せる画像の最大枚数。
  static const int snsShareMaxCount = 4;
}
