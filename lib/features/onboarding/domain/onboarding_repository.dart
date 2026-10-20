import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/onboarding_config.dart';

// ══════════════════════════════════════════════════════════
// オンボーディング 既読フラグの永続化リポジトリ
//
// SharedPreferences への直接アクセスをこのクラスに集約する。
// state/ 層（OnboardingController）からのみ呼び出すこと。
// ui/ から直接 import しない。
// ══════════════════════════════════════════════════════════
class OnboardingRepository {
  OnboardingRepository._();

  // 他機能のキーとの衝突を防ぐため 'onboarding_seen_' プレフィックスを付与する。
  // 末尾は OnboardingTopic.name（例: onboarding_seen_drawing）。
  static const _keyPrefix = 'onboarding_seen_';

  static String _key(OnboardingTopic topic) => '$_keyPrefix${topic.name}';

  /// [topic] の案内を既に表示済みか
  static Future<bool> isSeen(OnboardingTopic topic) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(topic)) ?? false;
  }

  /// [topic] の案内を表示済みとして記録する
  static Future<void> markSeen(OnboardingTopic topic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(topic), true);
  }

  /// 全ての案内を未表示（初回状態）に戻す。メンテナンス画面から使用する。
  /// このクラスが管理するキー（OnboardingTopic ごとのフラグ）だけを削除し、
  /// 他機能の SharedPreferences には触れない。
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final topic in OnboardingTopic.values) {
      await prefs.remove(_key(topic));
    }
  }
}
