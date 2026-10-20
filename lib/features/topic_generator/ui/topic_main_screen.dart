import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/topic_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../state/topic_provider.dart';

// ══════════════════════════════════════════════════════════
// お題ジェネレーター メイン画面
//
// 1〜3の選択項目は ListWheelScrollView によるスロット風の縦リールで
// 表示する（TopicConfig の仮データ・各3件）。
//   ・決定ボタン：現在3つのリールが示している組み合わせでお題を確定
//   ・ランダムボタン：3つのリールをランダムな位置までスピンさせるだけ
//     （確定はしない。確定するには続けて「決定」ボタンを押す）
// 確定したお題は topicProvider（お題エリア表示用）と履歴（直近10件）に
// 保存される。履歴画面からの選択・コピーボタンも本画面で完結する。
// ══════════════════════════════════════════════════════════
class TopicMainScreen extends ConsumerStatefulWidget {
  const TopicMainScreen({super.key});

  @override
  ConsumerState<TopicMainScreen> createState() => _TopicMainScreenState();
}

class _TopicMainScreenState extends ConsumerState<TopicMainScreen> {
  static const double _reelItemExtent = 36;
  static const List<List<String>> _reelOptions = [
    TopicConfig.situations,
    TopicConfig.compositions,
    TopicConfig.timeLimits,
  ];

  final List<FixedExtentScrollController> _controllers = List.generate(
    _reelOptions.length,
    (_) => FixedExtentScrollController(),
  );

  /// 各リールの現在の選択インデックス（スクロール中も含めて追従させる）
  final List<int> _selectedIndexes = List.filled(_reelOptions.length, 0);

  final _random = Random();
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    // 画面を開いたときは、履歴の最新のお題を表示する（履歴が空なら何も表示しない）。
    ref.read(topicProvider.notifier).showLatestFromHistory();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _combine(List<int> indexes) {
    return [
      for (var i = 0; i < _reelOptions.length; i++)
        _reelOptions[i][indexes[i]],
    ].join('\n');
  }

  Future<void> _decide() async {
    final topic = _combine(_selectedIndexes);
    await ref.read(topicProvider.notifier).decide(topic);
  }

  Future<void> _spinRandom() async {
    if (_isSpinning) return;
    setState(() => _isSpinning = true);

    final targets = [
      for (final options in _reelOptions) _random.nextInt(options.length),
    ];

    // 3つのリールを少しずつタイミングをずらしてスピンさせる（スロット演出）。
    for (var i = 0; i < _controllers.length; i++) {
      final optionCount = _reelOptions[i].length;
      // 同じ位置で止まっても回転した感を出すため、1〜2周余分に回す。
      final extraLoops = 1 + _random.nextInt(2);
      final targetItem = _controllers[i].selectedItem +
          extraLoops * optionCount +
          ((targets[i] - (_controllers[i].selectedItem % optionCount)) %
              optionCount);
      unawaited(_controllers[i].animateToItem(
        targetItem,
        duration: Duration(milliseconds: 500 + i * 150),
        curve: Curves.easeOutCubic,
      ));
    }

    await Future.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;
    // ランダムはリールを回すだけ。お題の確定・履歴への追加は「決定」ボタン
    // を押したときに行う（ランダム直後に気に入らなければ再度回せるように）。
    setState(() => _isSpinning = false);
  }

  Future<void> _copy(String topic) async {
    await Clipboard.setData(
        ClipboardData(text: topic.replaceAll('\n', ' ／ ')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.topicCopyDone)),
    );
  }

  Future<void> _openHistory() async {
    final selected = await Navigator.push(
      context,
      AppRouter.topicHistory(),
    );
    if (selected != null) {
      await ref.read(topicProvider.notifier).applyFromHistory(selected);
    } else {
      // 選択せずに戻った場合：履歴をすべて削除していたら、前回のお題を
      // 残さず何も表示しない状態にする。
      await ref.read(topicProvider.notifier).clearIfHistoryEmpty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = ref.watch(topicProvider);

    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.featureTopic,
        backgroundColor: AppColors.theme,
      ),
      body: SafeArea(
        child: LayoutBuilder(
        builder: (context, constraints) {
          final double outerPad =
              (constraints.maxWidth * AppValues.outerPadRatio)
                  .clamp(AppValues.outerPadMin, AppValues.outerPadMax);

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: outerPad, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopicArea(topic: topic, onCopy: _copy),
                // テーマ欄（お題エリア）と選択欄（1〜3のリール）の仕切り
                const SizedBox(height: 16),
                Divider(height: 1, thickness: 1, color: AppColors.border),
                const SizedBox(height: 16),
                _TopicReel(
                  label: AppStrings.topicSelector1Label,
                  options: TopicConfig.situations,
                  controller: _controllers[0],
                  itemExtent: _reelItemExtent,
                  onSelectedItemChanged: (i) => _selectedIndexes[0] = i,
                ),
                const SizedBox(height: 12),
                _TopicReel(
                  label: AppStrings.topicSelector2Label,
                  options: TopicConfig.compositions,
                  controller: _controllers[1],
                  itemExtent: _reelItemExtent,
                  onSelectedItemChanged: (i) => _selectedIndexes[1] = i,
                ),
                const SizedBox(height: 12),
                _TopicReel(
                  label: AppStrings.topicSelector3Label,
                  options: TopicConfig.timeLimits,
                  controller: _controllers[2],
                  itemExtent: _reelItemExtent,
                  onSelectedItemChanged: (i) => _selectedIndexes[2] = i,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSpinning ? null : _openHistory,
                        icon: const Icon(Icons.history),
                        label: Text(AppStrings.topicHistoryButton),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.theme,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSpinning ? null : _decide,
                        child: Text(AppStrings.dialogDecide),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSpinning ? null : _spinRandom,
                        icon: const Icon(Icons.shuffle),
                        label: Text(AppStrings.topicRandomButton),
                      ),
                    ),
                  ],
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

// ── お題エリア ───────────────────────────────────────────
class _TopicArea extends StatelessWidget {
  final String? topic;
  final ValueChanged<String> onCopy;

  const _TopicArea({required this.topic, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              // お題が未生成の間は何も表示しない（案内文なども出さない）。
              child: Center(
                child: topic == null
                    ? const SizedBox.shrink()
                    : Text(
                        topic!,
                        style: const TextStyle(fontSize: 17, height: 1.6),
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: topic == null ? null : () => onCopy(topic!),
                icon: const Icon(Icons.copy, size: 18),
                label: Text(AppStrings.topicCopyButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 1〜3 選択項目：スロット風リール ───────────────────────
class _TopicReel extends StatefulWidget {
  final String label;
  final List<String> options;
  final FixedExtentScrollController controller;
  final double itemExtent;
  final ValueChanged<int> onSelectedItemChanged;

  const _TopicReel({
    required this.label,
    required this.options,
    required this.controller,
    required this.itemExtent,
    required this.onSelectedItemChanged,
  });

  @override
  State<_TopicReel> createState() => _TopicReelState();
}

class _TopicReelState extends State<_TopicReel> {
  /// 現在中央（選択位置）にある選択肢のインデックス。
  /// 選択中の選択肢を大きく・太字・テーマカラーで目立たせるために保持する。
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final options = widget.options;
    final controller = widget.controller;
    final itemExtent = widget.itemExtent;
    final onSelectedItemChanged = widget.onSelectedItemChanged;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          // ラベルとリールの仕切り（縦線）
          Container(
            width: 1,
            height: itemExtent * 3,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.border,
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: itemExtent * 3,
                  child: ListWheelScrollView.useDelegate(
                    controller: controller,
                    itemExtent: itemExtent,
                    diameterRatio: 1.6,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (i) {
                      final index = i % options.length;
                      onSelectedItemChanged(index);
                      setState(() => _current = index);
                    },
                    childDelegate: ListWheelChildLoopingListDelegate(
                      children: [
                        for (var n = 0; n < options.length; n++)
                          Center(
                            child: Text(
                              options[n],
                              // 選択中は大きく・太字・テーマカラー、それ以外は
                              // 小さめ・グレーにして違いをはっきりさせる。
                              style: n == _current
                                  ? TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.theme,
                                    )
                                  : TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    height: itemExtent,
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void unawaited(Future<void> future) {}
