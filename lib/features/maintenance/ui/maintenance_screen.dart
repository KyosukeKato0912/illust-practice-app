import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/growth_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../../../shared/testdata/growth_testdata.dart';
import '../../growth/state/growth_practice_log_provider.dart';
import '../../growth/state/growth_provider.dart';
import '../../habit/state/habit_practice_provider.dart';

// ══════════════════════════════════════════════════════════
// メンテナンス画面
//
// 各機能に散らばっている「検証用」フラグ・数値を、実機を操作する前に
// アプリ内から切り替えられるようにするための画面。
// AppConfig.featureMaintenance が true の間だけホーム画面から
// 遷移できる（false にすればボタンごと非表示になり、リリース可能な
// 状態になる）。
//
// ── 設計方針 ──
// ・画面上の変更は、他の設定画面（習慣化サポート設定など）と違い
//   Hive等には一切保存しない。「決定」ボタンで初めて各機能の
//   実際の状態（既存のProvider／Repository）に反映される。
// ・アプリを再起動すれば、この画面自体の状態は必ずリリース時の
//   初期値からやり直しになる（＝検証用の変更が本番に残る心配がない）。
// ・AppBar右上の「初期状態に戻す」は、画面の選択状態をリリース時の
//   値に戻したうえで、即座に反映まで行う
//   （habit_settings_screen.dart の「初期状態に戻す」と同じ考え方）。
//
// ── 現在の項目 ──
//   1. 成長記録：保持上限到達フラグ（GrowthNotifier経由でHiveの
//      実フラグを直接ON/OFFする）。
//      スイッチ自体は画面を開くたびに必ずfalse（リリース時の初期値）
//      から始まる。今実際に動作に使われている値は、スイッチとは別に
//      「現在の設定：ON/OFF」として常時表示する（ref.watchでリアル
//      タイムに反映）。
//   2. 成長記録：保持上限枚数（growthMaxRecordCountProvider経由）。
//      入力欄は画面を開くたびに必ず GrowthConfig.maxRecordCount
//      （リリース時の初期値＝300）から始まる。実際に判定・自動削除に
//      使われている現在値も同様に別途表示する。
//   3. 成長記録：データソース（growthDataSourceModeProvider経由、
//      実データ／テストデータ／併用の3択）。
//   4. 習慣化サポート：データソース（habitDataSourceModeProvider経由、
//      同3択）。
//      3・4とも、画面を開くたびに必ず「実データ」から始まる。
//      「併用」はテストデータと実データを日付ごとに合算して扱うモード
//      （例：テストデータで過去分を作り、今日は実際にアップロードして
//      継続日数マイルストーンの挙動を確認する、といった検証に使う）。
//   5. テストデータ生成条件（growthTestDataConfigProvider経由、
//      成長記録・習慣化サポート共通）。開始日・終了日・1日あたり枚数・
//      1件あたりの所要時間を指定する。入力欄は画面を開くたびに必ず
//      GrowthTestDataConfig.initial()（リリース時の初期値）から始まる。
//   6. 習慣化サポート：登録件数表示（habitShowDebugDataCountProvider
//      経由）。継続カレンダー下に登録件数・記録日数を表示するかどうか。
//      スイッチは画面を開くたびに必ずfalse（非表示）から始まる。
//
// 今後の項目を追加する際は、_MaintenanceScreenState に編集用フィールドを
// 増やし、_decide() / _resetToDefault() にそれぞれの反映・初期化処理を
// 追記していく。
// ══════════════════════════════════════════════════════════
String _dataSourceModeLabel(GrowthDataSourceMode mode) {
  switch (mode) {
    case GrowthDataSourceMode.real:
      return AppStrings.maintenanceDataSourceRealLabel;
    case GrowthDataSourceMode.test:
      return AppStrings.maintenanceDataSourceTestLabel;
    case GrowthDataSourceMode.merged:
      return AppStrings.maintenanceDataSourceMergedLabel;
  }
}

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() =>
      _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  // ── 成長記録：保持上限到達フラグ（画面上の未反映の選択値）──
  // 画面を開くたび（＝アプリ起動のたび）に必ずリリース時の初期値
  // （false＝未到達）から始める。現在の実際の値は
  // ref.watch(growthMaxCountReachedProvider) を別途表示して確認できる
  // ようにする。
  bool _maxCountReached = false;

  // ── 成長記録：保持上限枚数（画面上の未反映の選択値）──
  // 画面を開くたびに必ず GrowthConfig.maxRecordCount（リリース時の
  // 初期値）から始める。
  late final TextEditingController _maxRecordCountController =
      TextEditingController(text: '${GrowthConfig.maxRecordCount}');

  // ── 成長記録／習慣化サポート：データソース（実データ／テストデータ／
  //    併用、画面上の未反映の選択値）── 画面を開くたびに必ず real
  // （リリース時の初期値）から始める。
  GrowthDataSourceMode _growthDataSourceMode = GrowthDataSourceMode.real;
  GrowthDataSourceMode _habitDataSourceMode = GrowthDataSourceMode.real;
  bool _habitShowDebugDataCount = false;

  // ── テストデータ生成条件（画面上の未反映の選択値）──
  // 画面を開くたびに必ず GrowthTestDataConfig.initial()（リリース時の
  // 初期値）から始める。
  late DateTime _testDataStartDate;
  late DateTime _testDataEndDate;
  late final TextEditingController _testDataCountPerDayController;
  late final TextEditingController _testDataMinutesController;

  @override
  void initState() {
    super.initState();
    final defaults = GrowthTestDataConfig.initial();
    _testDataStartDate = defaults.startDate;
    _testDataEndDate = defaults.endDate;
    _testDataCountPerDayController =
        TextEditingController(text: '${defaults.countPerDay}');
    _testDataMinutesController =
        TextEditingController(text: '${defaults.minutesPerEntry}');
  }

  @override
  void dispose() {
    _maxRecordCountController.dispose();
    _testDataCountPerDayController.dispose();
    _testDataMinutesController.dispose();
    super.dispose();
  }

  /// [_maxRecordCountController] の内容を検証し、問題なければ整数を返す。
  /// 不正な場合は SnackBar でエラーを表示して null を返す。
  int? _validatedMaxRecordCount() {
    final text = _maxRecordCountController.text.trim();
    final value = int.tryParse(text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.maintenanceMaxRecordCountError)),
      );
      return null;
    }
    return value;
  }

  /// テストデータ生成条件の入力欄を検証し、問題なければ
  /// [GrowthTestDataConfig] を返す。不正な場合は SnackBar でエラーを
  /// 表示して null を返す。
  GrowthTestDataConfig? _validatedTestDataConfig() {
    final countPerDay = int.tryParse(_testDataCountPerDayController.text.trim());
    if (countPerDay == null || countPerDay <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.maintenanceTestDataCountError)),
      );
      return null;
    }
    final minutesPerEntry =
        int.tryParse(_testDataMinutesController.text.trim());
    if (minutesPerEntry == null || minutesPerEntry <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.maintenanceTestDataMinutesError)),
      );
      return null;
    }
    if (_testDataStartDate.isAfter(_testDataEndDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.maintenanceTestDataRangeError)),
      );
      return null;
    }
    return GrowthTestDataConfig(
      startDate: _testDataStartDate,
      endDate: _testDataEndDate,
      countPerDay: countPerDay,
      minutesPerEntry: minutesPerEntry,
    );
  }

  Future<void> _pickTestDataDate({required bool isStart}) async {
    final initial = isStart ? _testDataStartDate : _testDataEndDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _testDataStartDate = picked;
      } else {
        _testDataEndDate = picked;
      }
    });
  }

  Future<void> _decide() async {
    final maxRecordCount = _validatedMaxRecordCount();
    if (maxRecordCount == null) return;
    final testDataConfig = _validatedTestDataConfig();
    if (testDataConfig == null) return;

    await ref
        .read(growthProvider.notifier)
        .setMaxCountReachedFlagForDebug(_maxCountReached);
    ref.read(growthMaxRecordCountProvider.notifier).setValue(maxRecordCount);
    ref
        .read(growthDataSourceModeProvider.notifier)
        .setValue(_growthDataSourceMode);
    ref
        .read(habitDataSourceModeProvider.notifier)
        .setValue(_habitDataSourceMode);
    ref
        .read(habitShowDebugDataCountProvider.notifier)
        .setValue(_habitShowDebugDataCount);
    ref.read(growthTestDataConfigProvider.notifier).setValue(testDataConfig);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.maintenanceApplyDone)),
    );
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.maintenanceResetTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(AppStrings.maintenanceResetMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.dialogCancel,
                style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.dialogReset),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _maxCountReached = false;
      _maxRecordCountController.text = '${GrowthConfig.maxRecordCount}';
      _growthDataSourceMode = GrowthDataSourceMode.real;
      _habitDataSourceMode = GrowthDataSourceMode.real;
      _habitShowDebugDataCount = false;
      final defaults = GrowthTestDataConfig.initial();
      _testDataStartDate = defaults.startDate;
      _testDataEndDate = defaults.endDate;
      _testDataCountPerDayController.text = '${defaults.countPerDay}';
      _testDataMinutesController.text = '${defaults.minutesPerEntry}';
    });
    await ref
        .read(growthProvider.notifier)
        .setMaxCountReachedFlagForDebug(false);
    ref.read(growthMaxRecordCountProvider.notifier).resetToDefault();
    ref.read(growthDataSourceModeProvider.notifier).resetToDefault();
    ref.read(habitDataSourceModeProvider.notifier).resetToDefault();
    ref.read(habitShowDebugDataCountProvider.notifier).resetToDefault();
    ref.read(growthTestDataConfigProvider.notifier).resetToDefault();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.maintenanceResetDone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // メンテナンス画面が保存する値ではなく、実際に今動作に使われている
    // 値（Hiveに永続化されている本物のフラグ／Provider経由の実効値）を
    // そのまま表示する。
    final currentMaxCountReached = ref.watch(growthMaxCountReachedProvider);
    final currentMaxRecordCount = ref.watch(growthMaxRecordCountProvider);
    final currentGrowthDataSourceMode =
        ref.watch(growthDataSourceModeProvider);
    final currentHabitDataSourceMode = ref.watch(habitDataSourceModeProvider);
    final currentHabitShowDebugDataCount =
        ref.watch(habitShowDebugDataCountProvider);
    final currentTestDataConfig = ref.watch(growthTestDataConfigProvider);

    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.maintenanceTitle,
        backgroundColor: AppColors.theme,
        actions: [
          IconButton(
            tooltip: AppStrings.maintenanceResetTitle,
            icon: const Icon(Icons.restart_alt),
            onPressed: _resetToDefault,
          ),
        ],
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
                // ── 成長記録 ─────────────────────────────
                _MaintenanceSectionCard(
                  title: AppStrings.maintenanceGrowthSectionTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 現在の実際の状態（読み取り専用） ──
                      _CurrentValueRow(
                        value: currentMaxCountReached
                            ? AppStrings.maintenanceOnLabel
                            : AppStrings.maintenanceOffLabel,
                        highlighted: currentMaxCountReached,
                      ),
                      const Divider(height: 20),
                      SwitchListTile(
                        value: _maxCountReached,
                        activeColor: AppColors.theme,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) =>
                            setState(() => _maxCountReached = v),
                        title: Text(
                          AppStrings.maintenanceMaxCountReachedLabel,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          _maxCountReached
                              ? AppStrings.maintenanceMaxCountReachedOnDesc
                              : AppStrings.maintenanceMaxCountReachedOffDesc,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ),
                      const Divider(height: 28),

                      // ── 保持上限枚数 ──
                      _CurrentValueRow(
                        value:
                            '$currentMaxRecordCount${AppStrings.maintenanceMaxRecordCountUnit}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.maintenanceMaxRecordCountLabel,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _maxRecordCountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          isDense: true,
                          suffixText: AppStrings.maintenanceMaxRecordCountUnit,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const Divider(height: 28),

                      // ── データソース（実データ／テストデータ／併用） ──
                      _CurrentValueRow(
                        value: _dataSourceModeLabel(currentGrowthDataSourceMode),
                        highlighted:
                            currentGrowthDataSourceMode !=
                                GrowthDataSourceMode.real,
                      ),
                      const SizedBox(height: 8),
                      _DataSourceModeSelector(
                        value: _growthDataSourceMode,
                        onChanged: (v) =>
                            setState(() => _growthDataSourceMode = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 習慣化サポート ─────────────────────────
                _MaintenanceSectionCard(
                  title: AppStrings.maintenanceHabitSectionTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── データソース（実データ／テストデータ／併用） ──
                      _CurrentValueRow(
                        value: _dataSourceModeLabel(currentHabitDataSourceMode),
                        highlighted:
                            currentHabitDataSourceMode !=
                                GrowthDataSourceMode.real,
                      ),
                      const SizedBox(height: 8),
                      _DataSourceModeSelector(
                        value: _habitDataSourceMode,
                        onChanged: (v) =>
                            setState(() => _habitDataSourceMode = v),
                      ),
                      const Divider(height: 28),

                      // ── 登録件数表示 ──
                      _CurrentValueRow(
                        value: currentHabitShowDebugDataCount
                            ? AppStrings.maintenanceOnLabel
                            : AppStrings.maintenanceOffLabel,
                        highlighted: currentHabitShowDebugDataCount,
                      ),
                      const Divider(height: 20),
                      SwitchListTile(
                        value: _habitShowDebugDataCount,
                        activeColor: AppColors.theme,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) =>
                            setState(() => _habitShowDebugDataCount = v),
                        title: Text(
                          AppStrings.maintenanceShowDebugDataCountLabel,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          _habitShowDebugDataCount
                              ? AppStrings.maintenanceShowDebugDataCountOnDesc
                              : AppStrings.maintenanceShowDebugDataCountOffDesc,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── テストデータ生成条件 ───────────────────
                _MaintenanceSectionCard(
                  title: AppStrings.maintenanceTestDataSectionTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CurrentValueRow(
                        value:
                            '${AppDateUtils.formatYMD(currentTestDataConfig.startDate)}'
                            '〜${AppDateUtils.formatYMD(currentTestDataConfig.endDate)}・'
                            '${currentTestDataConfig.countPerDay}${AppStrings.maintenanceTestDataCountUnit}/日・'
                            '${currentTestDataConfig.minutesPerEntry}${AppStrings.maintenanceTestDataMinutesUnit}',
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _MaintenanceDateField(
                              label: AppStrings.maintenanceTestDataStartDateLabel,
                              date: _testDataStartDate,
                              onTap: () => _pickTestDataDate(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MaintenanceDateField(
                              label: AppStrings.maintenanceTestDataEndDateLabel,
                              date: _testDataEndDate,
                              onTap: () => _pickTestDataDate(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings
                                      .maintenanceTestDataCountPerDayLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _testDataCountPerDayController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixText: AppStrings
                                        .maintenanceTestDataCountUnit,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.maintenanceTestDataMinutesLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _testDataMinutesController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixText: AppStrings
                                        .maintenanceTestDataMinutesUnit,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── 決定 ─────────────────────────────────
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.theme,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _decide,
                  child: Text(
                    AppStrings.maintenanceApplyButton,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// データソース3択（実データ／テストデータ／併用）セレクター
// 「併用」選択時は、下に補足説明を表示する。
// ══════════════════════════════════════════════════════════
class _DataSourceModeSelector extends StatelessWidget {
  final GrowthDataSourceMode value;
  final ValueChanged<GrowthDataSourceMode> onChanged;

  const _DataSourceModeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.maintenanceDataSourceLabel,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SegmentedButton<GrowthDataSourceMode>(
          segments: [
            ButtonSegment(
              value: GrowthDataSourceMode.real,
              label: Text(AppStrings.maintenanceDataSourceRealLabel),
            ),
            ButtonSegment(
              value: GrowthDataSourceMode.test,
              label: Text(AppStrings.maintenanceDataSourceTestLabel),
            ),
            ButtonSegment(
              value: GrowthDataSourceMode.merged,
              label: Text(AppStrings.maintenanceDataSourceMergedLabel),
            ),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.theme,
            selectedForegroundColor: Colors.white,
          ),
        ),
        if (value == GrowthDataSourceMode.merged) ...[
          const SizedBox(height: 8),
          Text(
            AppStrings.maintenanceDataSourceMergedDesc,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// 日付選択欄（ラベル＋タップで showDatePicker を開くボタン）
// ══════════════════════════════════════════════════════════
class _MaintenanceDateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _MaintenanceDateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(AppDateUtils.formatYMD(date)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// 「現在の設定：〇〇」読み取り専用表示
// メンテナンス画面が保存するものではなく、実際に今動作に使われている
// 値をそのまま見せるための行。
// ══════════════════════════════════════════════════════════
class _CurrentValueRow extends StatelessWidget {
  final String value;
  final bool highlighted;

  const _CurrentValueRow({required this.value, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          AppStrings.maintenanceCurrentValueLabel,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: highlighted ? AppColors.theme : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// メンテナンス項目セクションカード
// habit_settings_screen.dart の _SettingsSectionCard と同デザイン
// ══════════════════════════════════════════════════════════
class _MaintenanceSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _MaintenanceSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
