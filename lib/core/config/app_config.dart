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
  static const bool featureXSecDrawing    = true;  // X秒ドローイング
  static const bool featureTopicGenerator = false; // お題ジェネレーター
  static const bool featureGrowthRecord   = true;  // 成長記録
  static const bool featureHabitSupport   = true;  // 習慣化サポート
  static const bool featureProLesson      = false; // プロ絵師解説

  // ── Webサンプル版フラグ ─────────────────────────────────
  // true  → フィードバックリンクをホーム・X秒ドローイング終了画面に表示
  // false → 非表示（正式リリース時は false に戻すこと）
  static const bool showFeedbackLink = true;

  // ── メンテナンス機能 ────────────────────────────────────
  // 各機能に散らばっていた検証用フラグ・数値をアプリ内から操作できる
  // メンテナンス画面（features/maintenance）の表示フラグ。
  // ホーム画面にボタンとして表示するかどうかを切り替える
  // （準備中グレー表示ではなく、false の間はボタンごと非表示になる）。
  // ⚠ アプリ版としてリリースする際は、必ずこれを false にすること
  //   （このフラグを false にするだけでリリース可能な状態になるように、
  //   メンテナンス画面側の変更は一切保存されない設計になっている）。
  static const bool featureMaintenance = true;
}
