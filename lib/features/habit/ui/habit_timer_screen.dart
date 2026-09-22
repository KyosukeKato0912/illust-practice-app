import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../../../shared/components/banner_ad_widget.dart';
import '../state/habit_timer_notifier.dart';

// ══════════════════════════════════════════════════════════
// メリハリタイマー画面
//
// 上段：カウントダウン（作業中 or 休憩中）
// 下段：カウントアップ（0から経過作業時間を計測）
//
// ── フェーズ切替 ──
//   作業タイマーが 0 → 自動で休憩タイマーに切替（バナー通知）
//   休憩タイマーが 0 → 自動で作業タイマーに切替（バナー通知）
//   いずれもバックグラウンド時はシステム通知
//
// ── リセット ──
//   作業中リセットボタン：作業中・休憩中どちらでも作業開始時間に戻る
// ══════════════════════════════════════════════════════════
class HabitTimerScreen extends ConsumerStatefulWidget {
  final int? initialMinutes;
  final int? initialBreakMinutes;

  const HabitTimerScreen({
    super.key,
    this.initialMinutes,
    this.initialBreakMinutes,
  });

  @override
  ConsumerState<HabitTimerScreen> createState() => _HabitTimerScreenState();
}

class _HabitTimerScreenState extends ConsumerState<HabitTimerScreen> {
  HabitTimerNotifier? _notifier;

  // ── 総作業時間パネルの配色 ─────────────────────────
  // 作業中タイマーパネル（phaseBgColor 等）とは独立した変数。
  // 休憩中でも色は変化させない（常に固定）。
  static const Color _countUpBgColor = AppColors.themeLight;
  static const Color _countUpBorderColor = AppColors.themeBorder;
  static const Color _countUpTextColor = AppColors.themeDark;
  static const Color _countUpAccentColor = AppColors.theme;
  // 総作業時間パネル全体の透明度（0.0〜1.0）。ここを変更するだけで調整可能。
  static const double _countUpOpacity = 0.7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifier = ref.read(habitTimerProvider.notifier);
      _notifier!.init(
        initialMinutes: widget.initialMinutes,
        initialBreakMinutes: widget.initialBreakMinutes,
      );
    });
  }

  // ── 総作業時間リセット確認ダイアログ ─────────────────
  Future<void> _confirmResetCountUp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.habitCountUpResetDialogTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(AppStrings.habitCountUpResetDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppStrings.habitCountUpResetDialogCancel,
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.theme,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppStrings.habitCountUpResetDialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(habitTimerProvider.notifier).resetAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(habitTimerProvider);

    // justSwitched フラグは通知サービスが発行済みなのでここでは消費のみ
    ref.listen(habitTimerProvider, (prev, next) {
      if (next.justSwitched && !(prev?.justSwitched ?? false)) {
        ref.read(habitTimerProvider.notifier).consumeSwitched();
      }
    });

    // 現フェーズのラベルと色
    final phaseLabel =
        s.isBreak ? AppStrings.habitPhaseBreak : AppStrings.habitPhaseWork;
    // パネル：休憩中は緑系、作業中はテーマ色
    final phaseColor = s.isBreak ? Colors.green.shade800 : AppColors.themeDark;
    final phaseBgColor =
        s.isBreak ? Colors.green.shade50 : AppColors.themeLight;
    final phaseBorderColor =
        s.isBreak ? Colors.green.shade200 : AppColors.themeBorder;
    // ボタン色は常に紫（AppColors.theme）
    const phaseButtonColor = AppColors.theme;

    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.habitTimerTitle,
        backgroundColor: AppColors.theme,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double outerPad =
              (constraints.maxWidth * AppValues.outerPadRatio)
                  .clamp(AppValues.outerPadMin, AppValues.outerPadMax);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              outerPad,
              AppValues.habitTimerScrollPadding,
              outerPad,
              AppValues.habitTimerScrollPadding +
                  MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── カウントダウン ──────────────────────────
                _TimerPanel(
                  label: phaseLabel,
                  largeLabel: true,
                  displayText: s.isReady ? s.displayTime : '--:--',
                  bgColor: phaseBgColor,
                  borderColor: phaseBorderColor,
                  textColor: phaseColor,
                  onReset: s.isReady
                      ? () =>
                          ref.read(habitTimerProvider.notifier).resetCountDown()
                      : null,
                ),
                const SizedBox(height: 20),

                // ── カウントアップ（総作業時間：独立した固定配色）──
                Opacity(
                  opacity: _countUpOpacity,
                  child: _TimerPanel(
                    label: AppStrings.habitCountUpLabel,
                    largeLabel: true,
                    displayText: s.displayCountUp,
                    bgColor: _countUpBgColor,
                    borderColor: _countUpBorderColor,
                    textColor: _countUpTextColor,
                    accentColor: _countUpAccentColor,
                    onReset: s.countUpSeconds > 0
                        ? () => _confirmResetCountUp()
                        : null,
                  ),
                ),
                const SizedBox(height: 32),

                // ── 開始 / 一時停止 / 再開ボタン ─────────────
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          !s.isReady ? Colors.grey.shade300 : phaseButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: !s.isReady
                        ? null
                        : s.isRunning
                            ? () =>
                                ref.read(habitTimerProvider.notifier).pause()
                            : () =>
                                ref.read(habitTimerProvider.notifier).start(),
                    icon: Icon(
                      s.isRunning ? Icons.pause : Icons.play_arrow,
                      size: 28,
                    ),
                    label: Text(
                      s.isRunning
                          ? AppStrings.habitTimerPause
                          : (s.remainingSeconds <
                                  (s.isBreak
                                      ? s.breakTotalSeconds
                                      : s.totalSeconds)
                              ? AppStrings.habitTimerResume
                              : AppStrings.habitTimerStart),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // ── バナー広告 ────────────────────────────────
                const Center(child: BannerAdWidget()),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// タイマーパネル（カウントダウン・カウントアップ共用）
//
// パネル横幅は親の最大幅（開始ボタンと同幅）に伸張。
// リセットボタンはパネル右端に Stack で重ねて配置。
// ══════════════════════════════════════════════════════════
class _TimerPanel extends StatelessWidget {
  final String label;
  final bool largeLabel;
  final String displayText;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final Color accentColor;
  final VoidCallback? onReset;

  // リセットボタンのサイズ
  static const double _resetSize = 72.0;
  static const double _resetRight = 12.0;

  const _TimerPanel({
    required this.label,
    this.largeLabel = false,
    required this.displayText,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    this.accentColor = AppColors.theme,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ラベル
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: largeLabel ? 20 : 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 6),
        // パネル＋リセットボタンを Stack で重ねる
        Stack(
          alignment: Alignment.centerRight,
          children: [
            // タイマーパネル（全幅）
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  displayText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            // リセットボタン（右端に重ねる）
            Positioned(
              right: _resetRight,
              child: SizedBox(
                width: _resetSize,
                height: _resetSize,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    backgroundColor: Colors.white.withOpacity(0.85),
                    side: BorderSide(color: accentColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onReset,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.replay, size: 24),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.habitTimerReset,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
