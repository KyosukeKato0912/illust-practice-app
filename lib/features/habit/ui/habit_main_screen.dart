import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/habit_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../../../shared/components/banner_ad_widget.dart';
import '../../growth/domain/practice_day.dart';
import '../state/habit_practice_provider.dart';

// ══════════════════════════════════════════════════════════
// 習慣化サポート メイン画面
//
// 継続カレンダー・メリハリタイマーボタン・設定ボタンを表示する。
// 継続カレンダーは成長記録のアップロード完了画面（_GrowthMonthCalendar）と
// 同じデザイン（1行目：曜日ラベル、2行目：日付＋花丸を1セルにまとめた行）を
// 週表示向けに踏襲している。
// 余白・パディング・カラーは AppValues / AppColors の共通定数を使用。
//
// ⚠ 専用のHabitRecordモデルは持たない。
//   データは成長記録のアップロード時に作られる練習日の記録
//   （PracticeDay・habitPracticeDaysProvider）を参照する。
//   成長記録で画像を登録（ファイル・写真いずれか）したタイミングに
//   のみデータが作られ、画像を削除しても記録は残り続ける。
//   習慣化サポート・成長記録どちらの継続カレンダーも同じ記録を
//   参照する（メリハリタイマー自体は記録を作らない）。
//   作業時間の吹き出しには、アップロード時に任意入力された所要時間の
//   その日の合計（PracticeDay.totalMinutes）を使用する。
// ══════════════════════════════════════════════════════════
class HabitMainScreen extends ConsumerStatefulWidget {
  const HabitMainScreen({super.key});

  @override
  ConsumerState<HabitMainScreen> createState() => _HabitMainScreenState();
}

class _HabitMainScreenState extends ConsumerState<HabitMainScreen> {
  // ── 表示週の基準日（月曜日）────────────────────────────
  // 初期値：画面を開いた時点の今日が属する週の月曜日（initState で設定）
  late DateTime _weekMonday;

  // ── 現在吹き出しを表示中の日付キー（"yyyy-MM-dd"）────────
  // null のときはどの吹き出しも表示していない。
  // 単一値で管理することで「別の花丸をタップしたら
  // 表示中の吹き出しを閉じて新しい吹き出しを開く」を実現する。
  String? _openTooltipKey;

  @override
  void initState() {
    super.initState();
    _weekMonday = _todayMonday; // 画面を開いたら常に今日が属する週を表示
  }

  // ── 表示週の日付リスト（月〜日、7日分）──────────────────
  List<DateTime> get _weekDays => AppDateUtils.getWeekDates(_weekMonday);

  // ── 期間ラベル文字列 ─────────────────────────────────────
  String get _dateRangeLabel {
    final end = _weekMonday.add(const Duration(days: 6));
    return '${AppDateUtils.formatYMD(_weekMonday)}～${AppDateUtils.formatYMD(end)}';
  }

  // ── 今日が属する週の月曜日 ───────────────────────────────
  static DateTime get _todayMonday => AppDateUtils.mondayOf(DateTime.now());

  // ── 現在表示中の週が今週かどうか ────────────────────────
  bool get _isCurrentWeek =>
      _weekMonday.isAtSameMomentAs(_todayMonday);

  // ── 今日の週に戻る ───────────────────────────────────────
  void _goToToday() {
    setState(() {
      _weekMonday = _todayMonday;
      _openTooltipKey = null; // 週が変わるので開いていた吹き出しは閉じる
    });
  }

  // ── 前の週に切り替える ───────────────────────────────────
  void _goToPreviousWeek() {
    setState(() {
      _weekMonday = _weekMonday.subtract(const Duration(days: 7));
      _openTooltipKey = null;
    });
  }

  // ── 次の週に切り替える ───────────────────────────────────
  void _goToNextWeek() {
    setState(() {
      _weekMonday = _weekMonday.add(const Duration(days: 7));
      _openTooltipKey = null;
    });
  }

  // ── 吹き出しの開閉をトグル ───────────────────────────────
  // 同じセルを再タップ：閉じる
  // 別のセルをタップ：表示中の吹き出しを閉じて新しいセルを開く
  void _toggleTooltip(String dateKey) {
    setState(() {
      _openTooltipKey = (_openTooltipKey == dateKey) ? null : dateKey;
    });
  }

  // ── カレンダーピッカーを開き、選択週に切り替える ──────────
  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekMonday,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: '週を選択してください',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.theme,
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _weekMonday = AppDateUtils.mondayOf(picked);
        _openTooltipKey = null; // 週が変わるので開いていた吹き出しは閉じる
      });
    }
  }

  // ── 練習日の記録から表示週の日付ごとの作業時間合計を集計 ──
  // 戻り値：キー＝"yyyy-MM-dd"、値＝その日の作業時間合計(分)
  // データがない日はマップに含まれない（= 花丸なし）。
  // 所要時間はアップロード時の任意入力のため、未入力のアップロードは
  // 0分として合計済み（PracticeDay.totalMinutes）。
  Map<String, int> _buildDailyTotals(
    List<DateTime> weekDays,
    List<PracticeDay> allDays,
  ) {
    final weekSet = {
      for (final d in weekDays) AppDateUtils.dateKey(d),
    };
    final Map<String, int> totals = {};
    for (final day in allDays) {
      final key = AppDateUtils.dateKey(day.date);
      if (weekSet.contains(key)) {
        totals[key] = (totals[key] ?? 0) + day.totalMinutes;
      }
    }
    return totals;
  }

  // ── 練習日の記録全体から「記録のある日付」の集合を作成 ──
  // 連続日数の判定には表示週外のデータも必要なため、
  // 表示週で絞り込む前の全期間データから集合を作る。
  Set<String> _buildRecordedDateKeys(List<PracticeDay> allDays) => {
        for (final day in allDays) AppDateUtils.dateKey(day.date),
      };

  // ── 指定日が属する連続記録区間の「総日数」を計算する ────
  // 指定日自体に記録がない場合は 0 を返す。
  // 前後両方向に記録が途切れるまで辿り、区間全体の長さを返す。
  //
  // 「21日目以降は1日目からその日までが濃い黄色になる」仕様のため、
  // 色判定は「その日までの連続日数」ではなく
  // 「その日が含まれる連続区間が現時点で何日続いているか」で行う。
  // 例：6/1〜6/25まで毎日記録がある場合、6/21時点で区間長が21に達するため
  //     6/1〜6/21までのセルが一斉に濃い黄色になる。
  int _streakSpanAt(DateTime date, Set<String> recordedDateKeys) {
    final key = AppDateUtils.dateKey(date);
    if (!recordedDateKeys.contains(key)) return 0;

    // 過去方向の連続日数（指定日を含む）
    int backCount = 0;
    DateTime cursor = date;
    while (recordedDateKeys.contains(AppDateUtils.dateKey(cursor))) {
      backCount++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // 未来方向の連続日数（指定日翌日から、ただし「今日」より先は数えない）
    // ※ 今日以降の未確定な日付まで連続とみなさないようにするため。
    int forwardCount = 0;
    cursor = date.add(const Duration(days: 1));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    while (!cursor.isAfter(todayDate) &&
        recordedDateKeys.contains(AppDateUtils.dateKey(cursor))) {
      forwardCount++;
      cursor = cursor.add(const Duration(days: 1));
    }

    return backCount + forwardCount;
  }

  // ── 連続区間の長さに応じたセル背景色を返す ─────────────
  // 記録なし、または連続1日のみ：白
  // 区間長 2〜(しきい値-1)：薄い黄色
  // 区間長 しきい値以上：濃い黄色（区間全体が濃い黄色になる）
  Color _streakColor(DateTime date, Set<String> recordedDateKeys) {
    final span = _streakSpanAt(date, recordedDateKeys);
    if (span < 2) return Colors.white;
    if (span < AppValues.habitStreakDarkThresholdDays) {
      return AppColors.habitStreakLight;
    }
    return AppColors.habitStreakDark;
  }

  @override
  Widget build(BuildContext context) {
    // 継続カレンダーの元データ（HabitConfig.useTestData に応じて実データ／
    // テストデータを切替）は habit_practice_provider.dart に集約している。
    // 復帰促進通知の最終練習日と常に同じ元データを参照するため、
    // ここでは直接分岐しない。
    final allDays = ref.watch(habitPracticeDaysProvider);
    final weekDays = _weekDays;
    final dailyTotals = _buildDailyTotals(weekDays, allDays);
    final recordedDateKeys = _buildRecordedDateKeys(allDays);

    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.habitTitle,
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
              AppValues.settingsScrollPadding,
              outerPad,
              AppValues.settingsScrollPadding +
                  MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 表題（中央揃え）──────────────────────────
                Text(
                  AppStrings.habitCalendarTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                // ── 今日に戻るボタン（週切り替えの上段）──────────
                // 週切り替え行と重ならないよう、別の段に置く。
                // 今週を表示中はボタンを出さないが、段の高さは常に確保し、
                // 下の週切り替え・カレンダーの位置がズレないようにする。
                SizedBox(
                  height: 28,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _isCurrentWeek
                        ? null
                        : GestureDetector(
                            onTap: _goToToday,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.themeLight,
                                border: Border.all(
                                    color: AppColors.themeBorder, width: 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.today,
                                      size: 12, color: AppColors.themeDark),
                                  const SizedBox(width: 3),
                                  Text(
                                    AppStrings.habitGoToToday,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.themeDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),

                // ── 期間ラベル＋週切り替え ────────────────────
                // 日付リンクは前週/次週ボタン（32px）と同等かやや大きめの
                // 文字サイズにする。狭い画面ではみ出さないよう、
                // ラベル部分のみ FittedBox で縮小する（ボタンは固定サイズ）。
                SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _WeekNavButton(
                        icon: Icons.chevron_left,
                        onPressed: _goToPreviousWeek,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: GestureDetector(
                          onTap: _pickWeek,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _dateRangeLabel,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.theme,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.theme,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.calendar_today,
                                    size: 22, color: AppColors.theme),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _WeekNavButton(
                        icon: Icons.chevron_right,
                        onPressed: _goToNextWeek,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── カレンダーグリッド ────────────────────────
                _ContinuityCalendar(
                  weekDays: weekDays,
                  dailyTotals: dailyTotals,
                  streakColors: {
                    for (final d in weekDays)
                      AppDateUtils.dateKey(d): _streakColor(d, recordedDateKeys),
                  },
                  todayKey: AppDateUtils.dateKey(DateTime.now()),
                  openTooltipKey: _openTooltipKey,
                  onToggleTooltip: _toggleTooltip,
                ),
                const SizedBox(height: 32),

                // ── 【検証用】登録件数表示 ────────────────────
                if (HabitConfig.showDebugDataCount) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DebugCountChip(
                        label: AppStrings.habitDebugDataCountLabel,
                        value: '${allDays.fold<int>(0, (sum, d) => sum + d.uploadCount)}'
                            '${AppStrings.habitDebugDataCountSuffix}',
                      ),
                      const SizedBox(width: 12),
                      _DebugCountChip(
                        label: AppStrings.habitDebugDaysCountLabel,
                        value: '${recordedDateKeys.length}'
                            '${AppStrings.habitDebugDaysCountSuffix}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ── メリハリタイマーボタン ────────────────────
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.theme,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () =>
                      Navigator.push(context, AppRouter.habitTimer()),
                  icon: const Icon(Icons.timer_outlined),
                  label: Text(
                    AppStrings.habitTimerButton,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 設定ボタン ────────────────────────────────
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.theme,
                    side: const BorderSide(color: AppColors.theme),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () =>
                      Navigator.push(context, AppRouter.habitSettings()),
                  icon: const Icon(Icons.settings),
                  label: Text(
                    AppStrings.habitSettingsButton,
                    style: const TextStyle(fontSize: 16),
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
// 【検証用】登録件数チップ
//
// HabitConfig.showDebugDataCount が true の間のみ表示される。
// ══════════════════════════════════════════════════════════
class _DebugCountChip extends StatelessWidget {
  final String label;
  final String value;

  const _DebugCountChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.themeLight,
        border: Border.all(color: AppColors.themeBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.themeDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 継続カレンダー
//
// 曜日ラベル行＋日付セル行（7列）の2行構成。
// 成長記録のアップロード完了画面（_GrowthMonthCalendar）と同じデザイン
// （日付セルに「日付＋花丸」をまとめて表示）を、週表示（1週間分）向けに
// 踏襲している。
// ══════════════════════════════════════════════════════════
class _ContinuityCalendar extends StatelessWidget {
  final List<DateTime> weekDays;       // 7要素（月〜日）
  final Map<String, int> dailyTotals;  // キー="yyyy-MM-dd", 値=作業時間合計(分)
  final Map<String, Color> streakColors; // キー="yyyy-MM-dd", 値=記録セル背景色
  final String todayKey;               // 今日の日付キー（強調表示の判定用）
  final String? openTooltipKey;        // 現在開いている吹き出しの日付キー
  final void Function(String dateKey) onToggleTooltip;

  const _ContinuityCalendar({
    required this.weekDays,
    required this.dailyTotals,
    required this.streakColors,
    required this.todayKey,
    required this.openTooltipKey,
    required this.onToggleTooltip,
  });

  // 成長記録のアップロード完了画面（_GrowthMonthCalendar）と同じ寸法
  static const double _headerH = 24.0;
  static const double _rowH = 56.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 曜日ラベル（月・火・水…の1文字）────────────────
        SizedBox(
          height: _headerH,
          child: Row(
            children: List.generate(
              7,
              (i) => Expanded(
                child: _WeekdayCell(text: AppStrings.habitWeekdays[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        // ── 1週間分の日付セル（日付＋花丸を1セルにまとめる）──
        SizedBox(
          height: _rowH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: weekDays.map((date) {
              final key = AppDateUtils.dateKey(date);
              return Expanded(
                child: _DayCell(
                  date: date,
                  hasRecord: dailyTotals.containsKey(key),
                  totalMinutes: dailyTotals[key] ?? 0,
                  backgroundColor: streakColors[key] ?? Colors.white,
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
// 週切り替えボタン（前週／次週）
//
// shared/patterns/full_image_screen.dart の _NavButton と
// 同じデザイン（角丸・テーマカラー背景・白アイコン）を踏襲。
// こちらは期間ラベル横に置く小型サイズで使用する。
// ══════════════════════════════════════════════════════════
class _WeekNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _WeekNavButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.theme,
        foregroundColor: Colors.white,
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Icon(icon, size: 18),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 曜日ラベルセル（1文字表示：月・火・水…）
// ══════════════════════════════════════════════════════════
class _WeekdayCell extends StatelessWidget {
  final String text;

  const _WeekdayCell({required this.text});

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
// 日付セル
//
// 日付番号＋（記録がある日のみ）花丸を1セル内にまとめて表示する。
// 成長記録のアップロード完了画面（_GrowthDayCell）と同じデザイン。
// 花丸タップで親（_HabitMainScreenState）の onTap を呼び出し、
// どのセルの吹き出しを開くかを親で一元管理する。
// これにより、別のセルをタップすると表示中の吹き出しは自動的に
// 閉じ、新しいセルの吹き出しに切り替わる。
// 吹き出しには、その日の作業時間の合計（分）を表示する。
// 週の途中で月が替わることがあるため、1日のセルのみ「月/日」表記にする。
// ══════════════════════════════════════════════════════════
class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool hasRecord;
  final int totalMinutes;
  final Color backgroundColor;
  final bool isToday;
  final bool isOpen;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.hasRecord,
    required this.totalMinutes,
    required this.backgroundColor,
    required this.isToday,
    required this.isOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayText = date.day == 1 ? '${date.month}/1' : '${date.day}';
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: isToday ? AppColors.theme : AppColors.themeBorder,
          width: isToday ? 2 : 0.6,
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
                dayText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: Colors.black87,
                ),
              ),
              if (hasRecord)
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Center(
                      child: Image.asset(
                        HabitConfig.currentFlowerCircleAssetPath,
                        width: 30,
                        height: 30,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // ── 吹き出し ─────────────────────────────────
          if (hasRecord && isOpen)
            Positioned(
              bottom: 44,
              child: GestureDetector(
                onTap: onTap, // 吹き出しタップで閉じる
                child: _TooltipBubble(
                  label: totalMinutes == 0
                      ? AppStrings.habitTooltipNoTime
                      : '$totalMinutes${AppStrings.habitTooltipMinSuffix}',
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
class _TooltipBubble extends StatelessWidget {
  final String label;

  const _TooltipBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 吹き出し本体 ──────────────────────────────────
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
        // ── 吹き出しの三角形（下向き）────────────────────
        CustomPaint(
          size: const Size(14, 8),
          painter: _TrianglePainter(color: AppColors.themeDark),
        ),
      ],
    );
  }
}

// ── 下向き三角形の CustomPainter ────────────────────────
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

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
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
