import 'package:flutter/material.dart';
import '../../../core/config/onboarding_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/components/app_bar_widget.dart';

// ══════════════════════════════════════════════════════════
// ヘルプ画面
//
// 初回オンボーディング（各機能の案内）を、いつでも見返すための一覧画面。
// ホーム画面の AppBar にあるヘルプボタンから開く。
// 項目を選ぶと、対応する案内を OnboardingScreen（見返しモード）で表示する。
//
// ・見返しても既読の記録は変更しない（初回案内の表示状態には影響しない）。
// ・項目は OnboardingTopic.values の順に、OnboardingConfig から自動生成する
//   （案内を追加したときは OnboardingConfig を直せばここにも反映される）。
// ══════════════════════════════════════════════════════════
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const double _contentMaxWidth = 480;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.helpTitle,
        backgroundColor: AppColors.theme,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 8, 4, 16),
                  child: Text(
                    AppStrings.helpDescription,
                    style: TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
                for (final topic in OnboardingTopic.values)
                  _HelpTopicTile(topic: topic),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 一覧の1項目（アイコン・名称・矢印）
// ══════════════════════════════════════════════════════════
class _HelpTopicTile extends StatelessWidget {
  final OnboardingTopic topic;

  const _HelpTopicTile({required this.topic});

  @override
  Widget build(BuildContext context) {
    final pages = OnboardingConfig.pagesOf(topic);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          pages.isNotEmpty ? pages.first.icon : Icons.help_outline,
          color: AppColors.theme,
        ),
        title: Text(OnboardingConfig.labelOf(topic)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.push(context, AppRouter.onboardingReview(topic)),
      ),
    );
  }
}
