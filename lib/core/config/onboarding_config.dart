import 'package:flutter/material.dart';
import '../constants/app_strings.dart';

// ══════════════════════════════════════════════════════════
// 初回オンボーディング コンフィグ
//
// 各機能を初めて開いたときに1度だけ表示する案内画面の
// 「対象（OnboardingTopic）」と「ページ内容（アイコン・見出し・本文）」を
// 一元管理する。文言そのものは AppStrings に定義し、ここでは対応付けのみ行う。
//
// ・ページ数は機能ごとに自由（現状は各2ページ）。
// ・案内を追加・変更するときはこのファイルと AppStrings だけを直せばよい。
// ══════════════════════════════════════════════════════════

/// オンボーディングの対象。`name` が既読フラグの保存キーに使われるため、
/// 既存の値の名前を変更しないこと（変更すると既読が失われ再表示される）。
enum OnboardingTopic { home, drawing, topic, growth, habit }

/// 1ページ分の案内内容
class OnboardingPageDef {
  final IconData icon;
  final String title;
  final String body;

  const OnboardingPageDef({
    required this.icon,
    required this.title,
    required this.body,
  });
}

abstract class OnboardingConfig {
  static const List<OnboardingPageDef> _home = [
    OnboardingPageDef(
      icon: Icons.brush,
      title: AppStrings.onboardingHomeP1Title,
      body: AppStrings.onboardingHomeP1Body,
    ),
    OnboardingPageDef(
      icon: Icons.touch_app,
      title: AppStrings.onboardingHomeP2Title,
      body: AppStrings.onboardingHomeP2Body,
    ),
  ];

  static const List<OnboardingPageDef> _drawing = [
    OnboardingPageDef(
      icon: Icons.timer,
      title: AppStrings.onboardingDrawingP1Title,
      body: AppStrings.onboardingDrawingP1Body,
    ),
    OnboardingPageDef(
      icon: Icons.tune,
      title: AppStrings.onboardingDrawingP2Title,
      body: AppStrings.onboardingDrawingP2Body,
    ),
  ];

  static const List<OnboardingPageDef> _topic = [
    OnboardingPageDef(
      icon: Icons.lightbulb_outline,
      title: AppStrings.onboardingTopicP1Title,
      body: AppStrings.onboardingTopicP1Body,
    ),
    OnboardingPageDef(
      icon: Icons.shuffle,
      title: AppStrings.onboardingTopicP2Title,
      body: AppStrings.onboardingTopicP2Body,
    ),
  ];

  static const List<OnboardingPageDef> _growth = [
    OnboardingPageDef(
      icon: Icons.photo_library,
      title: AppStrings.onboardingGrowthP1Title,
      body: AppStrings.onboardingGrowthP1Body,
    ),
    OnboardingPageDef(
      icon: Icons.trending_up,
      title: AppStrings.onboardingGrowthP2Title,
      body: AppStrings.onboardingGrowthP2Body,
    ),
  ];

  static const List<OnboardingPageDef> _habit = [
    OnboardingPageDef(
      icon: Icons.hourglass_bottom,
      title: AppStrings.onboardingHabitP1Title,
      body: AppStrings.onboardingHabitP1Body,
    ),
    OnboardingPageDef(
      icon: Icons.calendar_month,
      title: AppStrings.onboardingHabitP2Title,
      body: AppStrings.onboardingHabitP2Body,
    ),
  ];

  /// [topic] のページ一覧を返す
  static List<OnboardingPageDef> pagesOf(OnboardingTopic topic) {
    switch (topic) {
      case OnboardingTopic.home:
        return _home;
      case OnboardingTopic.drawing:
        return _drawing;
      case OnboardingTopic.topic:
        return _topic;
      case OnboardingTopic.growth:
        return _growth;
      case OnboardingTopic.habit:
        return _habit;
    }
  }
}
