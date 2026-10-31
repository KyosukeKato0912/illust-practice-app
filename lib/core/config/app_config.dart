// ══════════════════════════════════════════════════════════
// アプリ全体のフィーチャーフラグ・共通設定
//
// 機能のリリース管理はここで一元管理する。
// 新機能を実装したら対応するフラグを true に変更すること。
// ══════════════════════════════════════════════════════════
abstract class AppConfig {
  // ── 機能リリースフラグ ──────────────────────────────────
  // true  → ホームボタン有効（実装済み・リリース対象）
  // false → ホームボタン無効（未実装・準備中）
  static const bool featureXSecDrawing = true; // X秒ドローイング
  static const bool featureTopicGenerator = true; // お題ジェネレーター
  static const bool featureGrowthRecord = true; // 成長記録
  static const bool featureHabitSupport = true; // 習慣化サポート
  static const bool featureProLesson = false; // プロ絵師解説

  // ── フィードバックリンク ────────────────────────────────
  // フィードバックリンク機能は全ての版に残し、表示/非表示のみ切り替える。
  // true  → フィードバックリンクをホーム・X秒ドローイング終了画面に表示
  // false → 非表示（正式リリース時は false に戻すこと）
  static const bool showFeedbackLink = false;

  // ── メンテナンス機能 ────────────────────────────────────
  // 各機能に散らばっていた検証用フラグ・数値をアプリ内から操作できる
  // メンテナンス画面（features/maintenance）の表示フラグ。
  // メンテナンス画面は全ての版に機能として残し、表示/非表示のみ切り替える。
  // ホーム画面にボタンとして表示するかどうかを切り替える
  // （準備中グレー表示ではなく、false の間はボタンごと非表示になる）。
  // ⚠ ユーザーに見せない版では、必ずこれを false にすること。
  //   メンテナンス画面の入力状態（データソース・保持上限・テストデータ条件・
  //   件数表示）は保存されず、アプリ再起動でリリース時の初期値に戻る。
  //   ただし「保持上限到達フラグ」（Hive）と「初回オンボーディングのリセット」
  //   （SharedPreferences）は、押した時点で実データに作用し、永続化される。
  static const bool featureMaintenance = false;

  // ── デバッグログ ────────────────────────────────────────
  // true  → AppLogger.log() の内容を logcat / コンソールに出力する
  //         （通知スケジュールの診断など、原因調査用の詳細ログも含む）
  // false → 一切出力しない（通常運用・リリース時の既定値）
  // バグ調査のときだけ true にして再ビルドする。調査後は false に戻すこと。
  // ※ kDebugMode には連動しない（リリースビルドの実機調査でも使えるようにしている）
  static const bool enableDebugLog = false;

  // ── 検証用フラグ（メンテナンス画面の初期値）──────────────
  // 各機能の動作確認用フラグ。いずれも「リリース時の初期値」であり、
  // 実際に使われる値は各機能の Provider 経由の値。メンテナンス画面から
  // 検証用に切り替えられるが、切り替えは保存されず、アプリ起動のたびに
  // ここで定義した値へ戻る。リリース時は false のままにすること。

  /// 【検証用】成長記録の一覧を実データ（Hive）の代わりに
  /// shared/testdata/growth_testdata.dart のテストデータで表示するかどうか。
  ///
  /// ⚠ 実際に使われる値は [growthDataSourceModeProvider]
  ///   （features/growth/state/growth_practice_log_provider.dart）経由の値
  ///   （real/test/merged の3値）。このProviderはこの定数（false→real）を
  ///   初期値として使う。
  ///   習慣化サポート側の表示切替は [habitUseTestData]
  ///   （実際には habitDataSourceModeProvider）で独立して管理しており、
  ///   本フラグとは連動しない。
  static const bool growthUseTestData = false;

  /// 【検証用】習慣化サポートの継続カレンダーを、実データ
  /// （growthProvider）の代わりに shared/testdata/growth_testdata.dart
  /// のテストデータで表示するかどうか。
  ///
  /// [growthUseTestData] とは独立して切替できる
  /// （例：成長記録メイン画面は実データのまま、習慣化サポート側だけ
  /// テストデータで継続カレンダーの配色を確認する、といった使い方を想定）。
  ///
  /// ⚠ 実際に使われる値は [habitDataSourceModeProvider]
  ///   （features/habit/state/habit_practice_provider.dart）経由の値
  ///   （real/test/merged の3値）。このProviderはこの定数を初期値として使う。
  static const bool habitUseTestData = false;

  /// 【検証用】継続カレンダーの下に、現在登録されている件数
  /// （データ総数・記録のある日数）を表示するかどうか。
  ///
  /// ⚠ 実際に使われる値は [habitShowDebugDataCountProvider]
  ///   （features/habit/state/habit_practice_provider.dart）経由の値。
  ///   このProviderはこの定数を初期値として使う。
  static const bool habitShowDebugDataCount = false;
}
