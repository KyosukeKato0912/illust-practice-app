import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/habit_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/growth_record.dart';
import '../domain/growth_streak_utils.dart';
import '../state/growth_pdf_controller.dart';
import '../state/growth_practice_log_provider.dart';
import '../state/growth_provider.dart';
import '../../../core/constants/app_values.dart';

// ══════════════════════════════════════════════════════════
// アップロード完了画面
//
// 「イラストを追加しました」の表示に加え、今回のアップロードで
// 更新された成長記録の継続カレンダーを表示する。
// [isMaxCountReached] が true の場合（保持上限枚数にちょうど到達した
// アップロード時のみ）、[isStreakMilestoneReached] が true の場合
// （今日を含めた連続アップロード日数が [GrowthConfig.streakMilestoneDays]
// にちょうど到達した時のみ）、それぞれ特別メッセージを表示する。
// 両方trueの場合は「連続日数メッセージ→空行→上限到達メッセージ」の順で
// 1つのテキストにまとめて表示する（PDFボタンは上限到達時のみ表示）。
//
// 継続カレンダーは features/habit/ui/habit_main_screen.dart の
// _ContinuityCalendar と同じ配色ルール（連続記録日数に応じて
// 白 → 薄い黄色 → 濃い黄色）・同じ花丸画像（HabitConfig）を踏襲するが、
// 表示範囲は完了画面向けに以下のとおりとする：
//   ・週切り替え・週ピッカーは持たず、「今日が属する月」を表示する
//   ・月の1日・末日が週の途中から始まる場合は、前月末・翌月頭の日付も
//     週を埋めるために表示する（淡色表示で当月日と区別）
//   ・週が縦に複数行（4〜6行）並ぶ、通常のカレンダーアプリに近いレイアウト
//   ・1セルに「日付＋花丸（記録がある日のみ）」をまとめて表示する
//     （habit側の「曜日／日付／記録」3段構成は週単位表示向けのため、
//     月単位表示ではセル内にまとめる形に変更している）
//   ・吹き出しは作業時間ではなく、その日の追加枚数（例：'2枚'）を表示する
// ══════════════════════════════════════════════════════════
class UploadCompleteScreen extends ConsumerStatefulWidget {
  final bool isMaxCountReached;
  final bool isStreakMilestoneReached;

  // ── 演出アニメーション（フェードイン）の発生条件 ─────────
  // いずれも GrowthNotifier.confirmUpload の戻り値をそのまま渡す。
  // 詳細な判定ロジックはそちら側のdocコメントを参照。
  final bool showFlowerFadeIn;
  final bool showColorFadeIn;
  final bool showMessageFadeIn;
  final bool showPdfButtonFadeIn;

  const UploadCompleteScreen({
    super.key,
    this.isMaxCountReached = false,
    this.isStreakMilestoneReached = false,
    this.showFlowerFadeIn = false,
    this.showColorFadeIn = false,
    this.showMessageFadeIn = false,
    this.showPdfButtonFadeIn = false,
  });

  @override
  ConsumerState<UploadCompleteScreen> createState() =>
      _UploadCompleteScreenState();
}

class _UploadCompleteScreenState extends ConsumerState<UploadCompleteScreen> {
  // ── 現在吹き出しを表示中の日付キー（"yyyy-MM-dd"）────────
  // null のときはどの吹き出しも表示していない。
  String? _openTooltipKey;

  /// PDF生成中フラグ（多重タップ防止・ローディング表示用）。
  /// [widget.isMaxCountReached] が true の回（保持上限に初めて到達した
  /// アップロード完了時）のみ、本画面にもPDFボタンを表示する。
  bool _isGeneratingPdf = false;

  /// PDF生成中の進捗表示（例：'作成中:45%'）。生成中のみ非null。
  String? _pdfProgressLabel;

  // ── 演出アニメーション（花丸→色変け→メッセージ→PDFボタン） ──
  // 4種類とも一律0.5秒のフェードイン。実際に発生する演出のみを
  // この順番で積み上げてスケジュールする（発生しない段はスキップし、
  // 待ち時間を詰める）。花丸・色変けは今日のセル（_GrowthDayCell）側で
  // widget.showFlowerFadeIn／showColorFadeIn を見て自力でアニメーション
  // するため、ここでは特別メッセージ・PDFボタンの開始タイミングのみを
  // 管理する。
  static const _fadeInMs = 500;

  // 画面遷移アニメーション（ルートの出現）が完了してから演出を始める。
  // 遷移中に始めると、序盤の花丸のフェードインが見えなくなるため。
  bool _animationStarted = false;

  // アニメーション対象外（例：同じ日の2回目以降のアップロード）でも、
  // 表示すべき内容自体は最初から見えている状態にする。
  late bool _showMessage = !widget.showMessageFadeIn;
  late bool _showPdfButton = !widget.showPdfButtonFadeIn;

  @override
  void initState() {
    super.initState();
    // ModalRoute.of は initState 内では使えないため、初回フレーム後に
    // 遷移アニメーションの完了を待つ。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _waitForRouteTransition();
    });
  }

  void _waitForRouteTransition() {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _startFadeIns();
      return;
    }
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(listener);
        if (mounted) _startFadeIns();
      }
    }

    animation.addStatusListener(listener);
  }

  /// 遷移完了後に呼ばれ、花丸・色変け（今日のセル側）の開始を知らせ、
  /// 特別メッセージ・PDFボタンの表示タイミングをスケジュールする。
  void _startFadeIns() {
    var offsetMs = 0;
    if (widget.showFlowerFadeIn) offsetMs += _fadeInMs;
    if (widget.showColorFadeIn) offsetMs += _fadeInMs;
    final messageStartMs = offsetMs;
    if (widget.showMessageFadeIn) offsetMs += _fadeInMs;
    final pdfButtonStartMs = offsetMs;

    setState(() => _animationStarted = true);

    if (widget.showMessageFadeIn) {
      Future.delayed(Duration(milliseconds: messageStartMs), () {
        if (mounted) setState(() => _showMessage = true);
      });
    }
    if (widget.showPdfButtonFadeIn) {
      Future.delayed(Duration(milliseconds: pdfButtonStartMs), () {
        if (mounted) setState(() => _showPdfButton = true);
      });
    }
  }

  void _toggleTooltip(String dateKey) {
    setState(() {
      _openTooltipKey = (_openTooltipKey == dateKey) ? null : dateKey;
    });
  }

  // ── PDF書き出し（growth_main_screen.dart の _onPdfTap と同じ手順） ──
  // ⚠ ここでは成長記録メイン画面PDFボタンの「NEW」既読化は行わない。
  //   「NEW」は成長記録メイン画面のPDFボタンのみに紐づく表示のため、
  //   本画面からのダウンロードでは既読にしない。
  Future<void> _onPdfTap(List<GrowthRecord> records) async {
    if (records.isEmpty || _isGeneratingPdf) return;

    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await GrowthPdfController.build(
        records,
        onProgress: (percent) {
          if (mounted) {
            setState(() => _pdfProgressLabel =
                '${AppStrings.growthPdfProgressPrefix}$percent'
                '${AppStrings.growthPdfProgressSuffix}');
          }
        },
      );
      if (!mounted) return;
      await FilePicker.platform.saveFile(
        fileName: GrowthPdfController.buildFileName(DateTime.now()),
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
    } catch (e, st) {
      debugPrint('[GrowthPdfService] PDF生成に失敗しました: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.growthPdfGenerateError)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
          _pdfProgressLabel = null;
        });
      }
    }
  }

  // ── 「今日が属する月」を埋める週単位グリッドを組み立てる ──
  // 月の1日を含む週の月曜日から、月の末日を含む週の日曜日までを
  // 週（7日）単位のリストとして返す。月によって4〜6週になる。
  List<List<DateTime>> _buildMonthWeeks(DateTime today) {
    final firstOfMonth = DateTime(today.year, today.month, 1);
    final lastOfMonth = DateTime(today.year, today.month + 1, 0);
    final gridStart = AppDateUtils.mondayOf(firstOfMonth);
    final lastWeekMonday = AppDateUtils.mondayOf(lastOfMonth);
    final totalDays = lastWeekMonday.difference(gridStart).inDays + 7;
    final weekCount = totalDays ~/ 7;
    return List.generate(
      weekCount,
      (w) => List.generate(7, (d) => gridStart.add(Duration(days: w * 7 + d))),
    );
  }

  // ── 指定日が属する連続記録区間の「総日数」／セル色 ──────
  // ロジック本体は features/growth/domain/growth_streak_utils.dart に
  // 集約している（GrowthNotifier側でも演出判定に使うため）。
  int _streakSpanAt(DateTime date, Set<String> recordedDateKeys) =>
      GrowthStreakUtils.spanAt(date, recordedDateKeys);

  Color _streakColor(DateTime date, Set<String> recordedDateKeys) =>
      GrowthStreakUtils.colorAt(date, recordedDateKeys);

  @override
  Widget build(BuildContext context) {
    // 練習日の記録（画像を削除しても残る）。GrowthConfig.useTestData に従う
    final practiceDays = ref.watch(growthPracticeDaysProvider);
    // PDFボタン用（初解禁時初回のみ表示）。絞込の影響を受けない全件。
    final allRecords = ref.watch(growthProvider);

    // 連続日数マイルストーン・保持上限到達の特別メッセージを組み立てる。
    // 両方trueの場合は「連続日数→空行→上限到達」の順で1つにまとめる。
    final specialMessages = <String>[
      if (widget.isStreakMilestoneReached)
        AppStrings.growthUploadCompleteStreakMilestoneMessage,
      if (widget.isMaxCountReached)
        AppStrings.growthUploadCompleteMaxCountMessage.replaceAll(
          '{count}',
          '${ref.watch(growthMaxRecordCountProvider)}',
        ),
    ];
    final specialMessage = specialMessages.join('\n\n');
    final now = DateTime.now();

    final weeks = _buildMonthWeeks(now);
    final currentMonth = now.month;
    final currentYear = now.year;
    final todayKey = AppDateUtils.dateKey(now);

    // 全期間の「記録のある日付」集合（連続日数の判定には表示月外の
    // データも必要なため、月で絞り込む前の全件から作成する）
    final recordedDateKeys = <String>{
      for (final d in practiceDays) AppDateUtils.dateKey(d.date),
    };

    // ── 色変けアニメーションの開始色（色が実際に変わるセルのみ） ──
    // 連続記録は区間全体が同じ色になるため、今日のセルだけでなく連続区間
    // 内の他のセルも色が変わる（例：21日目に達すると、過去20日分も
    // 薄い黄色→濃い黄色に変わる）。これらも今日のセルと一緒に
    // アニメーションさせないと、最初から変わって見えてしまう。
    // 「今回の保存前」の状態は、今日の記録を除いた集合で再計算して得る。
    final previousColors = <String, Color>{};
    if (widget.showColorFadeIn) {
      final keysBeforeToday = {...recordedDateKeys}
        ..remove(AppDateUtils.dateKey(now));
      for (final week in weeks) {
        for (final d in week) {
          final key = AppDateUtils.dateKey(d);
          if (!recordedDateKeys.contains(key)) continue;
          // 今日のセルは「昨日時点の色」から（2日目＝白→薄い黄色、
          // 21日目＝薄い黄色→濃い黄色）。他のセルは今日を除いた状態の色から。
          final before = key == AppDateUtils.dateKey(now)
              ? _streakColor(
                  now.subtract(const Duration(days: 1)), keysBeforeToday)
              : _streakColor(d, keysBeforeToday);
          if (before != _streakColor(d, recordedDateKeys)) {
            previousColors[key] = before;
          }
        }
      }
    }

    // 表示グリッド内（前月末・翌月頭を含む）の日付ごとの追加枚数
    final gridSet = <String>{
      for (final week in weeks)
        for (final d in week) AppDateUtils.dateKey(d),
    };
    final Map<String, int> dailyCounts = {};
    for (final d in practiceDays) {
      final key = AppDateUtils.dateKey(d.date);
      if (gridSet.contains(key)) {
        dailyCounts[key] = (dailyCounts[key] ?? 0) + d.uploadCount;
      }
    }

    // 今日の作業時間合計（所要時間未入力のアップロードは0分として集計済み）
    final todayTotalDurationMin = practiceDays
        .where((d) => AppDateUtils.dateKey(d.date) == todayKey)
        .fold<int>(0, (sum, d) => sum + d.totalMinutes);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 72,
                color: AppColors.theme,
              ),
              const SizedBox(height: 20),
              const Text(
                AppStrings.growthUploadCompleteTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (specialMessages.isNotEmpty) ...[
                const SizedBox(height: 12),
                AnimatedOpacity(
                  opacity: _showMessage ? 1 : 0,
                  duration: const Duration(milliseconds: _fadeInMs),
                  child: Text(
                    specialMessage,
                    style: const TextStyle(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (widget.isMaxCountReached) ...[
                const SizedBox(height: 16),
                AnimatedOpacity(
                  opacity: _showPdfButton ? 1 : 0,
                  duration: const Duration(milliseconds: _fadeInMs),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.theme,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.disabledBackground,
                      disabledForegroundColor: AppColors.disabledText,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        _isGeneratingPdf ? null : () => _onPdfTap(allRecords),
                    icon: _isGeneratingPdf
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 20),
                    label: Text(
                      _pdfProgressLabel ??
                          AppStrings.growthUploadCompletePdfButton,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
              // ── 今日の作業時間合計（1分以上のときのみ表示） ──
              if (todayTotalDurationMin >= 1) ...[
                const SizedBox(height: 16),
                Text(
                  '${AppStrings.growthUploadCompleteTodayDurationLabel}　'
                  '$todayTotalDurationMin${AppStrings.growthDurationInputUnit}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.themeDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),

              // ── 継続カレンダー（今日が属する月） ────────────
              Text(
                '${AppStrings.growthCalendarTitle}'
                '（$currentYear${AppStrings.unitYear}'
                '$currentMonth${AppStrings.unitMonth}）',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _GrowthMonthCalendar(
                weeks: weeks,
                currentMonth: currentMonth,
                dailyCounts: dailyCounts,
                streakColors: {
                  for (final week in weeks)
                    for (final d in week)
                      AppDateUtils.dateKey(d): _streakColor(d, recordedDateKeys),
                },
                previousColors: previousColors,
                todayAnimateFlower: widget.showFlowerFadeIn,
                // 色変けは、花丸のフェードイン（0.5秒）が発生する場合はその後。
                colorDelayMs: widget.showFlowerFadeIn ? _fadeInMs : 0,
                startAnimation: _animationStarted,
                todayKey: todayKey,
                openTooltipKey: _openTooltipKey,
                onToggleTooltip: _toggleTooltip,
              ),

              const SizedBox(height: 40),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.theme,
                  side: const BorderSide(color: AppColors.theme),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // 本画面を「イラストを追加」画面へ置き換える。pushReplacement
                  // を使うことで、確定後に再度本画面へ戻ってきてもスタックの
                  // 深さが [成長記録メイン, 本画面] の2枚のまま保たれ、下の
                  // 「成長記録メインへ」ボタン（1回のpopを前提）が引き続き
                  // 正しく機能する。
                  Navigator.pushReplacement(context, AppRouter.growthUpload());
                },
                child: const Text(
                  AppStrings.growthUploadCompleteContinueButton,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.theme,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // アップロード画面・「続けて追加」いずれの経路でも本画面は
                  // pushReplacement で開かれるため、スタックには常に
                  // [成長記録メイン, 本画面] の2枚のみが積まれている。
                  // 1回のpopで成長記録メイン画面まで戻る。
                  Navigator.of(context).pop();
                },
                child: const Text(
                  AppStrings.growthUploadCompleteBackButton,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 成長記録 継続カレンダー（アップロード完了画面向け・月表示）
//
// 1行目：曜日ラベル（固定）
// 2行目以降：週（7日）× 4〜6行。各セルに日付＋花丸をまとめて表示する。
// 花丸画像は習慣化サポートの継続カレンダーと同じもの
// （HabitConfig.currentFlowerCircleAssetPath）をそのまま使用する。
// ══════════════════════════════════════════════════════════
class _GrowthMonthCalendar extends StatelessWidget {
  final List<List<DateTime>> weeks; // 週×7日
  final int currentMonth; // 当月かどうかの判定用（1〜12）
  final Map<String, int> dailyCounts; // キー="yyyy-MM-dd", 値=その日の追加枚数
  final Map<String, Color> streakColors; // キー="yyyy-MM-dd", 値=セル背景色
  final Map<String, Color> previousColors; // 色が変わるセルの開始色
  final bool todayAnimateFlower;
  final int colorDelayMs;
  final bool startAnimation;
  final String todayKey;
  final String? openTooltipKey;
  final void Function(String dateKey) onToggleTooltip;

  const _GrowthMonthCalendar({
    required this.weeks,
    required this.currentMonth,
    required this.dailyCounts,
    required this.streakColors,
    required this.previousColors,
    required this.todayAnimateFlower,
    required this.colorDelayMs,
    required this.startAnimation,
    required this.todayKey,
    required this.openTooltipKey,
    required this.onToggleTooltip,
  });

  static const double _headerH = AppValues.calendarHeaderHeight;
  static const double _weekRowH = AppValues.calendarRowHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 曜日ラベル（固定・1回のみ） ──────────────────
        SizedBox(
          height: _headerH,
          child: Row(
            children: List.generate(
              7,
              (i) => Expanded(
                child: _GrowthCalendarWeekdayCell(
                  text: AppStrings.growthWeekdays[i].substring(0, 1),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        // ── 週行（4〜6行） ───────────────────────────────
        for (final week in weeks)
          SizedBox(
            height: _weekRowH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: week.map((date) {
                final key = AppDateUtils.dateKey(date);
                final count = dailyCounts[key] ?? 0;
                return Expanded(
                  child: _GrowthDayCell(
                    date: date,
                    isCurrentMonth: date.month == currentMonth,
                    hasRecord: count > 0,
                    count: count,
                    backgroundColor: streakColors[key] ?? Colors.white,
                    previousColor: previousColors[key],
                    animateFlower: key == todayKey && todayAnimateFlower,
                    animateColor: previousColors.containsKey(key),
                    colorDelayMs: colorDelayMs,
                    startAnimation: startAnimation,
                    isToday: key == todayKey,
                    isOpen: openTooltipKey == key,
                    onTap: () => onToggleTooltip(key),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// 曜日ラベルセル（1文字表示：月・火・水…）
// ══════════════════════════════════════════════════════════
class _GrowthCalendarWeekdayCell extends StatelessWidget {
  final String text;

  const _GrowthCalendarWeekdayCell({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.themeLight,
        borderRadius: BorderRadius.circular(4),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.themeDark,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 日付セル（週行）
//
// 日付番号＋（記録がある日のみ）花丸を1セル内にまとめて表示する。
// 花丸タップで親（_UploadCompleteScreenState）の onToggleTooltip を
// 呼び出し、どのセルの吹き出しを開くかを親で一元管理する。
// 当月外の日付（前月末・翌月頭）は日付番号を淡色にして区別する。
// ══════════════════════════════════════════════════════════
class _GrowthDayCell extends StatefulWidget {
  final DateTime date;
  final bool isCurrentMonth;
  final bool hasRecord;
  final int count;
  final Color backgroundColor;
  // 色変けアニメーションの開始色。色が実際に変わるセル（今日のセル＋
  // 連続区間内の他のセル）にのみ渡される。nullの場合は色を静的に表示する。
  final Color? previousColor;
  // animateFlower は今日のセルのみtrueになりうる。false の場合は演出なしで
  // そのまま最終状態（花丸は不透明度1・色は最終色）を表示する
  // （例：同じ日の2回目以降のアップロード時）。
  final bool animateFlower;
  final bool animateColor;
  // 色変けの開始までの待ち時間（花丸のフェードインがある場合はその後に
  // なるよう、全セルで同じ値を渡して揃える）。
  final int colorDelayMs;
  // 演出の開始合図（画面遷移の完了後に true になる）。true になるまでは
  // 演出開始前の状態（花丸は透明・色は昨日時点の色）で待機する。
  final bool startAnimation;
  final bool isToday;
  final bool isOpen;
  final VoidCallback onTap;

  const _GrowthDayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.hasRecord,
    required this.count,
    required this.backgroundColor,
    this.previousColor,
    this.animateFlower = false,
    this.animateColor = false,
    this.colorDelayMs = 0,
    this.startAnimation = false,
    required this.isToday,
    required this.isOpen,
    required this.onTap,
  });

  @override
  State<_GrowthDayCell> createState() => _GrowthDayCellState();
}

// ── 今日のセルの演出アニメーション ──────────────────────
// 花丸・色変けとも一律0.5秒のフェードイン。両方発生する場合は
// 「花丸0.5秒 → 色変け0.5秒」の順（計1.0秒）、片方のみの場合は
// その0.5秒のみ。どちらも発生しない場合は静的に最終状態を表示する。
// 色変けは今日のセルだけでなく、色が変わる連続区間内の全セルが対象で、
// いずれも同じタイミング（colorDelayMs後）に一緒に変化する。
class _GrowthDayCellState extends State<_GrowthDayCell>
    with SingleTickerProviderStateMixin {
  bool get _animateFlower => widget.isToday && widget.animateFlower;
  bool get _animateColor =>
      widget.animateColor && widget.previousColor != null;
  bool get _animates => _animateFlower || _animateColor;

  // 花丸は0〜500ms、色変けは colorDelayMs から500ms。全体の長さはその最大値。
  int get _flowerMs => _animateFlower ? 500 : 0;
  int get _totalMs =>
      _animateColor ? widget.colorDelayMs + 500 : _flowerMs;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalMs),
  );

  late final Animation<double> _flowerAnimation = _animateFlower
      ? CurvedAnimation(
          parent: _controller,
          curve: Interval(0.0, _flowerMs / _totalMs, curve: Curves.easeOut),
        )
      : const AlwaysStoppedAnimation<double>(1.0);

  late final Animation<Color?> _colorAnimation = _animateColor
      ? ColorTween(begin: widget.previousColor, end: widget.backgroundColor)
          .animate(CurvedAnimation(
            parent: _controller,
            curve: Interval(widget.colorDelayMs / _totalMs, 1.0,
                curve: Curves.easeOut),
          ))
      : AlwaysStoppedAnimation<Color?>(widget.backgroundColor);

  @override
  void initState() {
    super.initState();
    if (_animates && widget.startAnimation) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _GrowthDayCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_animates && !oldWidget.startAnimation && widget.startAnimation) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    if (_animates) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animates) {
      return _buildCell(
        backgroundColor: widget.backgroundColor,
        flowerOpacity: 1,
        flowerOffset: 0,
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return _buildCell(
          backgroundColor: _colorAnimation.value ?? widget.backgroundColor,
          flowerOpacity: _flowerAnimation.value,
          // 下から上へ浮き上がってくるように、不透明度が低いほど
          // 下側にオフセットする。
          flowerOffset: (1 - _flowerAnimation.value) * 10,
        );
      },
    );
  }

  Widget _buildCell({
    required Color backgroundColor,
    required double flowerOpacity,
    required double flowerOffset,
  }) {
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: widget.isToday ? AppColors.theme : AppColors.themeBorder,
          width: widget.isToday ? 2 : 0.6,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                '${widget.date.day}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      widget.isToday ? FontWeight.bold : FontWeight.normal,
                  color: widget.isCurrentMonth
                      ? Colors.black87
                      : Colors.grey.shade400,
                ),
              ),
              if (widget.hasRecord)
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onTap,
                    child: Center(
                      child: Opacity(
                        opacity: flowerOpacity,
                        child: Transform.translate(
                          offset: Offset(0, flowerOffset),
                          child: Image.asset(
                            HabitConfig.currentFlowerCircleAssetPath,
                            width: 30,
                            height: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // ── 吹き出し ─────────────────────────────────
          if (widget.hasRecord && widget.isOpen)
            Positioned(
              bottom: 44,
              child: GestureDetector(
                onTap: widget.onTap, // 吹き出しタップで閉じる
                child: _GrowthTooltipBubble(
                  label:
                      '${widget.count}${AppStrings.growthTooltipCountSuffix}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 吹き出しウィジェット
// ══════════════════════════════════════════════════════════
class _GrowthTooltipBubble extends StatelessWidget {
  final String label;

  const _GrowthTooltipBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.themeDark,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(14, 8),
          painter: _GrowthTrianglePainter(color: AppColors.themeDark),
        ),
      ],
    );
  }
}

class _GrowthTrianglePainter extends CustomPainter {
  final Color color;
  const _GrowthTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GrowthTrianglePainter old) => old.color != color;
}
