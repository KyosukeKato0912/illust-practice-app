import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/config/app_config.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../../../shared/components/feedback_link_widget.dart';

// ══════════════════════════════════════════════════════════
// ホーム画面
//
// 5機能へのナビゲーションボタンを表示する。
// 未実装機能は [enabled: false] で「準備中」グレーボタンになる。
// AppConfig.featureMaintenance が true の間は、末尾にメンテナンス画面への
// ボタンも表示する（「準備中」表示ではなく、false の間はボタンごと
// 非表示になる）。
// ══════════════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.homeTitle,
        backgroundColor: AppColors.theme,
        showBackButton: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double outerPad =
              (constraints.maxWidth * AppValues.outerPadRatio)
                  .clamp(AppValues.outerPadMin, AppValues.outerPadMax);

          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: outerPad, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FeatureNavButton(
                    label: AppStrings.featureDrawing,
                    color: AppColors.theme,
                    enabled: AppConfig.featureXSecDrawing,
                    onTap: () =>
                        Navigator.push(context, AppRouter.drawing()),
                  ),
                  const SizedBox(height: 12),
                  _FeatureNavButton(
                    label: AppStrings.featureTopic,
                    color: AppColors.topicGenerator,
                    enabled: AppConfig.featureTopicGenerator,
                    onTap: () {}, // TODO: AppRouter.topic() に差し替える
                  ),
                  const SizedBox(height: 12),
                  _FeatureNavButton(
                    label: AppStrings.featureGrowth,
                    color: AppColors.theme,
                    enabled: AppConfig.featureGrowthRecord,
                    onTap: () =>
                        Navigator.push(context, AppRouter.growth()),
                  ),
                  const SizedBox(height: 12),
                  _FeatureNavButton(
                    label: AppStrings.featureHabit,
                    color: AppColors.theme,
                    enabled: AppConfig.featureHabitSupport,
                    onTap: () => Navigator.push(context, AppRouter.habit()),
                  ),
                  const SizedBox(height: 12),
                  _FeatureNavButton(
                    label: AppStrings.featureProLesson,
                    color: AppColors.proArtistLesson,
                    enabled: AppConfig.featureProLesson,
                    onTap: () {}, // TODO: AppRouter.proLesson() に差し替える
                  ),
                  if (AppConfig.featureMaintenance) ...[
                    const SizedBox(height: 12),
                    _FeatureNavButton(
                      label: AppStrings.featureMaintenance,
                      color: Colors.grey.shade700,
                      onTap: () =>
                          Navigator.push(context, AppRouter.maintenance()),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FeedbackLinkWidget(
                    label: AppStrings.feedbackLinkLabelHome,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 機能ナビゲーションボタン
// ══════════════════════════════════════════════════════════
class _FeatureNavButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _FeatureNavButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            enabled ? color : AppColors.disabled,
        foregroundColor:
            enabled ? Colors.white : AppColors.disabledText,
        padding: const EdgeInsets.symmetric(vertical: 32),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: enabled ? 2 : 0,
      ),
      onPressed: enabled ? onTap : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          if (!enabled) ...[
            const SizedBox(width: 8),
            Text(
              AppStrings.featureComingSoon,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
