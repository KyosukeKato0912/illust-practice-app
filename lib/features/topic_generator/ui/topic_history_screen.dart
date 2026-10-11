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
// 各行右端のゴミ箱ボタンで、確認ダイアログの上、その履歴を1件削除できる。
// ══════════════════════════════════════════════════════════
class TopicHistoryScreen extends ConsumerStatefulWidget {
  const TopicHistoryScreen({super.key});

  @override
  ConsumerState<TopicHistoryScreen> createState() =>
      _TopicHistoryScreenState();
}

class _TopicHistoryScreenState extends ConsumerState<TopicHistoryScreen> {
  int? _selectedIndex;

  /// 確認ダイアログの上、[index] 番目の履歴を削除する。
  /// 選択中の履歴を削除した場合は選択を解除し、それより前にある履歴を
  /// 削除した場合は選択位置を1つ前にずらす（同じ履歴を選び続けるため）。
  Future<void> _confirmAndDelete(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.topicHistoryDeleteDialogTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(AppStrings.topicHistoryDeleteDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.dialogCancel,
                style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.topicHistoryDeleteDialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(topicProvider.notifier).removeFromHistoryAt(index);
    ref.invalidate(topicHistoryProvider);
    if (!mounted) return;
    setState(() {
      final selected = _selectedIndex;
      if (selected == null) return;
      if (selected == index) {
        _selectedIndex = null;
      } else if (selected > index) {
        _selectedIndex = selected - 1;
      }
    });
  }

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
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSelected)
                                        Icon(Icons.check_circle,
                                            color: AppColors.theme),
                                      IconButton(
                                        tooltip:
                                            AppStrings.topicHistoryDeleteTooltip,
                                        icon: Icon(Icons.delete_outline,
                                            color: Colors.grey.shade600),
                                        onPressed: () =>
                                            _confirmAndDelete(index),
                                      ),
                                    ],
                                  ),
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
