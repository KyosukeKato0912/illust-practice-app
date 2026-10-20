import '../../../core/config/onboarding_config.dart';
import '../domain/onboarding_repository.dart';

// ══════════════════════════════════════════════════════════
// オンボーディング コントローラー（state/ 層）
//
// ui/ → state/ のみ参照というレイヤー依存ルールに沿って、
// OnboardingRepository（domain/）への直接アクセスをこの薄いラッパーに
// 集約する。
//
// ⚠ Riverpodは使わない：
//   既読の判定・記録は各案内画面の表示時・終了時に1回ずつ行うだけで、
//   画面をまたいで状態を保持し続ける必要がないため。
// ══════════════════════════════════════════════════════════
class OnboardingController {
  OnboardingController._();

  /// [topic] の案内を既に表示済みか
  static Future<bool> isSeen(OnboardingTopic topic) =>
      OnboardingRepository.isSeen(topic);

  /// [topic] の案内を表示済みとして記録する
  static Future<void> markSeen(OnboardingTopic topic) =>
      OnboardingRepository.markSeen(topic);

  /// 全ての案内を未表示（初回状態）に戻す（メンテナンス画面用）
  static Future<void> resetAll() => OnboardingRepository.resetAll();
}
