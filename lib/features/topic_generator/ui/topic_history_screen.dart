import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../state/topic_provider.dart';

// ══════════════════════════════════════════════════════════
// お題履歴画面
//
// 「企画書_ver3.xlsx」の UI設計_お題ジェネレーター シートに準拠。
// 直近10件分のお題履歴（topicHistoryProvider）をスクロールで表示する。
// 1件選んで「決定」を押すと、選択したお題を Navigator.pop の戻り値として
// TopicMainScreen に返す（TopicMainScreen 側で topicProvider に反映し、
// お題エリアに表示する）。
// ══════════════════════════════════════════════════════════
class TopicHistoryScreen extends ConsumerStatefulWidget {
  const TopicHistoryScreen({super.key});

  @override
  ConsumerState<TopicHistoryScreen> createState() =>
      _TopicHistoryScreenState();
}

class _TopicHistoryScreenState extends ConsumerState<TopicHistoryScreen> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(topicHistoryProvider);

    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.topicHistoryTitle,
        backgroundColor: AppColors.theme,
      ),
      body: SafeArea(
        child: LayoutBuilder(
        builder: (context, constraints) {
          final double outerPad =
              (constraints.maxWidth * AppValues.outerPadRatio)
                  .clamp(AppValues.outerPadMin, AppValues.outerPadMax);

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: outerPad, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: historyAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const _TopicHistoryEmptyState(),
                    data: (histories) => histories.isEmpty
                        ? const _TopicHistoryEmptyState()
                        : ListView.separated(
                            itemCount: histories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final isSelected = _selectedIndex == index;
                              return Card(
                                elevation: isSelected ? 3 : 1,
                                color: isSelected
                                    ? AppColors.theme
                                        .withOpacity(0.08)
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.theme
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: ListTile(
                                  title: Text(
                                    histories[index].replaceAll('\n', ' ／ '),
                                  ),
                                  trailing: isSelected
                                      ? Icon(Icons.check_circle,
                                          color: AppColors.theme)
                                      : null,
                                  onTap: () =>
                                      setState(() => _selectedIndex = index),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.theme,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final histories =
                          historyAsync.valueOrNull ?? const <String>[];
                      final index = _selectedIndex;
                      if (index == null || index >= histories.length) return;
                      Navigator.pop(context, histories[index]);
                    },
                    child: Text(AppStrings.dialogDecide),
                  ),
                ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }
}

class _TopicHistoryEmptyState extends StatelessWidget {
  const _TopicHistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            AppStrings.topicHistoryEmptyMessage,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.topicHistoryEmptyHint,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
