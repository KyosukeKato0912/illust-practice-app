// ══════════════════════════════════════════════════════════
// アプリ全体の数値・設定値定数
//
// 仕様変更時の修正箇所をここに集約する。
// ══════════════════════════════════════════════════════════
abstract class AppValues {
  // ── レイアウト ──────────────────────────────────────────
  /// 外側パディングの割合（画面幅に対する比率）
  static const double outerPadRatio = 0.05;

  /// 外側パディングの最小値（px）
  static const double outerPadMin = 8.0;

  /// 外側パディングの最大値（px）
  static const double outerPadMax = 240.0;

  // ── 画面下部の余白（デザイン上のベース値） ───────────────
  // 実際に確保する余白は必ず「本値 ＋ 端末の下部セーフエリア
  // （ジェスチャーナビゲーションバー等。MediaQuery.paddingOf(context).bottom）」
  // とすること。本値だけだと機種によりホームインジケーターに重なる。

  /// 画面下部に固定表示するボタン行の下余白（成長記録メイン画面など）
  static const double bottomActionRowPadding = 20.0;

  /// 拡大表示画面のピンチヒントなど、画面最下部のヒント文言の下余白
  static const double bottomHintPadding = 16.0;

  /// X秒ドローイング メイン画面：再生コントロール行の上下余白
  static const double controlRowPadding = 12.0;

  /// 各種設定画面：スクロール本文の上下余白（基本値）
  static const double settingsScrollPadding = 24.0;

  /// 習慣化サポート タイマー画面：スクロール本文の上下余白
  static const double habitTimerScrollPadding = 32.0;

  /// サムネイル一覧（グリッド）の上下余白
  static const double gridContentPadding = 12.0;

  // ── X秒ドローイング ─────────────────────────────────────
  /// 開始カウントダウン秒数
  static const int drawingCountdownSec = 3;

  /// 設定：切り替え時間の下限（秒）
  static const int drawingDurationMinSec = 30;

  /// 設定：切り替え時間の上限（秒）
  static const int drawingDurationMaxSec = 600;

  /// 設定：切り替え時間の変更単位（秒）
  static const int drawingDurationStepSec = 30;

  /// 設定：最大作業時間の下限（分）
  static const int drawingMaxWorkTimeMinMin = 1;

  /// 設定：最大作業時間の上限（分）
  static const int drawingMaxWorkTimeMaxMin = 100;

  /// 設定：最大作業時間の変更単位（分）
  static const int drawingMaxWorkTimeStepMin = 1;

  /// 最大作業時間「無制限」を表す値
  static const int drawingMaxWorkTimeUnlimited = 0;

  /// ドットインジケーターを表示する最大枚数
  static const int drawingDotIndicatorMaxCount = 20;

  // ── アセットパス ────────────────────────────────────────
  /// ポーズモデル画像の格納フォルダ
  static const String modelAssetFolder = 'assets/images/models/';

  // ── モデルカテゴリ ──────────────────────────────────────
  // NOTE: カテゴリ定義順は DrawingConfig.categories のリスト順で管理する

  // ── 習慣化サポート ───────────────────────────────────────
  /// 設定：メリハリタイマー 作業時間の下限（分）
  static const int habitTimerMinMinutes = 1;

  /// 設定：メリハリタイマー 作業時間の上限（分）
  static const int habitTimerMaxMinutes = 120;

  /// 設定：メリハリタイマー 休憩時間の下限（分）
  static const int habitBreakMinMinutes = 1;

  /// 設定：メリハリタイマー 休憩時間の上限（分）
  static const int habitBreakMaxMinutes = 60;

  /// 設定：作業開始促進通知の時刻を選べる分の刻み（分）。
  /// 60の約数であること。実機検証で短い間隔を試したいときは 1 にする。
  static const int habitReminderMinuteInterval = 30;

  /// 継続カレンダー：連続記録が濃い黄色になる日数のしきい値
  static const int habitStreakDarkThresholdDays = 21;

  /// 成長記録 継続カレンダー：連続記録が濃い黄色になる日数のしきい値
  static const int growthStreakDarkThresholdDays = 21;

  // ── Hive typeId 一覧（重複登録防止のため一元管理） ─────
  // GrowthRecord   : typeId = 0  （実装済み）
  //   ⚠ 習慣化サポートの継続カレンダーも本モデルを参照する
  //     （専用のHabitRecordモデルは持たない。データは成長記録で
  //     画像登録（ファイル・写真）した時にのみ作られる）
  // TopicHistory   : typeId = 2  （未実装）
  // AppSettings    : typeId = 3  （未実装）
}
