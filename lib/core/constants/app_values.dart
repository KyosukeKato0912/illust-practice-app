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

  /// 成長記録のサムネイル一覧の縦横比（幅:高さ）。
  /// ⚠ グリッド描画とドラッグ選択の当たり判定（幾何計算）の双方で
  ///   同じ値を使うこと。
  static const double growthThumbAspectRatio = 0.75;

  /// X秒ドローイング モデル一覧のサムネイルの縦横比（幅:高さ）
  static const double modelThumbAspectRatio = 0.75;

  /// 継続カレンダー（習慣化サポート／成長記録）の曜日ヘッダーの高さ
  static const double calendarHeaderHeight = 24.0;

  /// 継続カレンダー（習慣化サポート／成長記録）の1週分の行の高さ
  static const double calendarRowHeight = 56.0;

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

  /// モデル名ラベルを完全表示する時間（ミリ秒）
  static const int drawingModelLabelVisibleMs = 300;

  /// モデル名ラベルのフェードアウト時間（ミリ秒）
  static const int drawingModelLabelFadeMs = 200;

  /// 切り替えまでの残り秒数がこの値以下になると警告演出（点滅・色変化）を行う
  static const int drawingAlertThresholdSec = 5;

  /// ドットインジケーターを表示する最大枚数
  static const int drawingDotIndicatorMaxCount = 20;

  // ── アセットパス ────────────────────────────────────────
  /// ポーズモデル画像の格納フォルダ
  static const String modelAssetFolder = 'assets/images/models/';

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

  /// 基本セットの既定の作業時間（分）
  static const int habitDefaultTimerMinutes = 25;

  /// 基本セットの既定の休憩時間（分）
  static const int habitDefaultBreakMinutes = 5;

  /// 自由設定の既定の作業時間（分）
  static const int habitDefaultCustomTimerMinutes = 10;

  /// 自由設定の既定の休憩時間（分）
  static const int habitDefaultCustomBreakMinutes = 5;

  /// 作業開始促進通知の既定の時刻（時）
  static const int habitDefaultReminderHour = 12;

  /// 作業開始促進通知の既定の時刻（分）
  static const int habitDefaultReminderMinute = 0;

  /// 継続カレンダー：連続記録の目標日数（21日）。
  /// 濃い黄色への切り替えと、成長記録の継続お祝いメッセージの基準となる。
  static const int streakTargetDays = 21;

  /// 継続カレンダー：連続記録が濃い黄色になる日数のしきい値
  static const int habitStreakDarkThresholdDays = streakTargetDays;

  /// 成長記録 継続カレンダー：連続記録が濃い黄色になる日数のしきい値
  static const int growthStreakDarkThresholdDays = streakTargetDays;

  // ── Hive typeId 一覧（重複登録防止のため一元管理） ─────
  // GrowthRecord   : typeId = 0  （実装済み・TypeAdapterあり）
  //
  // ■ 以下のBoxはTypeAdapterを使わない（typeIdを消費しない）
  //   growth_meta            : フラグ類（プリミティブ値）
  //   growth_practice_log    : 練習日の記録（Map）。継続カレンダー用で、
  //                            習慣化サポートのカレンダーもこれを参照する
  //                            （専用のHabitRecordモデルは持たない）
  //   growth_serial_counters : 日別の連番カウンタ（int）
  //   topic_history          : お題履歴（文字列リスト）
  //
  // ■ typeId = 1 以降は現在どのモデルにも割り当てていない。
  //   TypeAdapterを持つモデルを追加する際は、本コメントに追記して
  //   重複を防ぐこと。
}
