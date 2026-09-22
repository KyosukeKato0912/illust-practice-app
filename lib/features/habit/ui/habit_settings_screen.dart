import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../../../shared/components/hold_repeat_icon_button.dart';
import '../domain/habit_settings.dart';
import '../state/habit_settings_controller.dart';
import '../state/habit_timer_notifier.dart';

// ══════════════════════════════════════════════════════════
// 習慣化サポート 設定画面
//
// ── セクション ──
//   1. メリハリタイマーセット（基本セット / 自由に設定）
//   2. 作業開始促進通知（ON/OFF + 時刻選択）
//
// ── AppBar ──
//   restart_alt : 確認ダイアログ → 全設定をデフォルトに戻す
// ══════════════════════════════════════════════════════════
class HabitSettingsScreen extends ConsumerStatefulWidget {
  const HabitSettingsScreen({super.key});

  @override
  ConsumerState<HabitSettingsScreen> createState() =>
      _HabitSettingsScreenState();
}

class _HabitSettingsScreenState extends ConsumerState<HabitSettingsScreen> {
  // ── タイマー設定 ──────────────────────────────────────
  bool _isPreset     = HabitSettingsController.defaultIsPreset;
  int  _timerMinutes = HabitSettingsController.defaultCustomTimerMinutes;
  int  _breakMinutes = HabitSettingsController.defaultCustomBreakMinutes;

  // ── 作業開始促進通知 ───────────────────────────────────
  bool _reminderEnabled = HabitSettingsController.defaultReminderEnabled;
  int  _reminderHour    = HabitSettingsController.defaultReminderHour;
  int  _reminderMinute  = HabitSettingsController.defaultReminderMinute;

  // ── 復帰促進通知 ───────────────────────────────────────
  bool _comebackEnabled = HabitSettingsController.defaultComebackEnabled;
  HabitComebackPeriod _comebackPeriod = HabitSettingsController.defaultComebackPeriod;

  bool _isLoading = true;

  // タイマーに渡す実効値（モードに応じて解決）
  int get _resolvedTimerMinutes => _isPreset
      ? HabitSettingsController.defaultTimerMinutes
      : _timerMinutes;
  int get _resolvedBreakMinutes => _isPreset
      ? HabitSettingsController.defaultBreakMinutes
      : _breakMinutes;

  // 通知時刻の表示文字列
  String get _reminderTimeLabel {
    final h = _reminderHour.toString().padLeft(2, '0');
    final m = _reminderMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final saved = await HabitSettingsController.load();
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _isPreset        = saved.isPreset;
        if (!saved.isPreset) {
          _timerMinutes  = saved.timerMinutes;
          _breakMinutes  = saved.breakMinutes;
        }
        _reminderEnabled = saved.reminderEnabled;
        _reminderHour    = saved.reminderHour;
        _reminderMinute  = saved.reminderMinute;
        _comebackEnabled = saved.comebackEnabled;
        _comebackPeriod  = saved.comebackPeriod;
      }
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await HabitSettingsController.save(
      isPreset:        _isPreset,
      timerMinutes:    _resolvedTimerMinutes,
      breakMinutes:    _resolvedBreakMinutes,
      reminderEnabled: _reminderEnabled,
      reminderHour:    _reminderHour,
      reminderMinute:  _reminderMinute,
      comebackEnabled: _comebackEnabled,
      comebackPeriod:  _comebackPeriod,
    );
    ref.read(habitTimerProvider.notifier).resetWithMinutes(
          minutes:      _resolvedTimerMinutes,
          breakMinutes: _resolvedBreakMinutes,
        );
  }

  Future<void> _onSaveOnly() async {
    await _saveSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppStrings.habitSettingsSaved),
          duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _onSaveAndStart() async {
    await _saveSettings();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AppRouter.habitTimer(
        initialMinutes:      _resolvedTimerMinutes,
        initialBreakMinutes: _resolvedBreakMinutes,
      ),
    );
  }

  Future<void> _onResetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.habitSettingsResetTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(AppStrings.habitSettingsResetMessage),
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

    await HabitSettingsController.clear();
    setState(() {
      _isPreset        = HabitSettingsController.defaultIsPreset;
      _timerMinutes    = HabitSettingsController.defaultCustomTimerMinutes;
      _breakMinutes    = HabitSettingsController.defaultCustomBreakMinutes;
      _reminderEnabled = HabitSettingsController.defaultReminderEnabled;
      _reminderHour    = HabitSettingsController.defaultReminderHour;
      _reminderMinute  = HabitSettingsController.defaultReminderMinute;
      _comebackEnabled = HabitSettingsController.defaultComebackEnabled;
      _comebackPeriod  = HabitSettingsController.defaultComebackPeriod;
    });
    ref.read(habitTimerProvider.notifier).resetWithMinutes(
          minutes:      _resolvedTimerMinutes,
          breakMinutes: _resolvedBreakMinutes,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.habitSettingsReset)),
    );
  }

  // 時刻ピッカー
  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.theme),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _reminderHour   = picked.hour;
      _reminderMinute = picked.minute;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.habitSettingsTitle,
        backgroundColor: AppColors.theme,
        actions: [
          IconButton(
            tooltip: AppStrings.habitSettingsResetTitle,
            icon: const Icon(Icons.restart_alt),
            onPressed: _isLoading ? null : _onResetToDefaults,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.theme))
          : LayoutBuilder(
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
                      // ── 1. メリハリタイマーセット ─────────────
                      _SettingsSectionCard(
                        title: AppStrings.habitSettingsModeTitle,
                        child: _ModeSelector(
                          isPreset: _isPreset,
                          onChanged: (v) => setState(() => _isPreset = v),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── 自由設定スライダー（自由モード時のみ）──
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: _isPreset
                            ? const SizedBox.shrink()
                            : Column(
                                children: [
                                  _SettingsSectionCard(
                                    title: AppStrings.habitSettingsTimerTitle,
                                    child: _MinutesSetting(
                                      minutes: _timerMinutes,
                                      minMinutes: AppValues.habitTimerMinMinutes,
                                      maxMinutes: AppValues.habitTimerMaxMinutes,
                                      onChanged: (v) => setState(
                                          () => _timerMinutes = v),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _SettingsSectionCard(
                                    title: AppStrings.habitSettingsBreakTitle,
                                    child: _MinutesSetting(
                                      minutes: _breakMinutes,
                                      minMinutes: AppValues.habitBreakMinMinutes,
                                      maxMinutes: AppValues.habitBreakMaxMinutes,
                                      onChanged: (v) => setState(
                                          () => _breakMinutes = v),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                      ),

                      // ── 2. 作業開始促進通知 ───────────────────
                      _SettingsSectionCard(
                        title: AppStrings.habitReminderSectionTitle,
                        child: _ReminderSetting(
                          enabled:    _reminderEnabled,
                          hour:       _reminderHour,
                          minute:     _reminderMinute,
                          timeLabel:  _reminderTimeLabel,
                          onToggle:   (v) =>
                              setState(() => _reminderEnabled = v),
                          onPickTime: _pickReminderTime,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── 3. 復帰促進通知 ───────────────────────
                      _SettingsSectionCard(
                        title: AppStrings.habitComebackSectionTitle,
                        child: _ComebackSetting(
                          enabled: _comebackEnabled,
                          period:  _comebackPeriod,
                          onToggle: (v) =>
                              setState(() => _comebackEnabled = v),
                          onPeriodChanged: (v) =>
                              setState(() => _comebackPeriod = v),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── 保存 ／ 保存して開始 ──────────────────
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.theme,
                                side: const BorderSide(color: AppColors.theme),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _onSaveOnly,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                AppStrings.habitSettingsSaveButton,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.theme,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _onSaveAndStart,
                              icon: const Icon(Icons.play_arrow),
                              label: Text(
                                AppStrings.habitSettingsSaveAndStartButton,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
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
// モード選択ウィジェット
// ══════════════════════════════════════════════════════════
class _ModeSelector extends StatelessWidget {
  final bool isPreset;
  final ValueChanged<bool> onChanged;

  const _ModeSelector({required this.isPreset, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              _ModeTab(
                label: AppStrings.habitModePreset,
                icon: Icons.auto_awesome,
                selected: isPreset,
                onTap: () => onChanged(true),
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(11)),
              ),
              _ModeTab(
                label: AppStrings.habitModeCustom,
                icon: Icons.tune,
                selected: !isPreset,
                onTap: () => onChanged(false),
                borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _ModeDescription(
            key: ValueKey(isPreset),
            isPreset: isPreset,
          ),
        ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.theme : Colors.transparent,
            borderRadius: borderRadius,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeDescription extends StatelessWidget {
  final bool isPreset;
  const _ModeDescription({super.key, required this.isPreset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.themeLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.themeBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPreset ? Icons.info_outline : Icons.edit_note,
            size: 16,
            color: AppColors.themeDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isPreset ? AppStrings.habitPresetDesc : AppStrings.habitCustomDesc,
              style: TextStyle(fontSize: 13, color: AppColors.themeDark),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 作業開始促進通知設定ウィジェット
// ══════════════════════════════════════════════════════════
class _ReminderSetting extends StatelessWidget {
  final bool enabled;
  final int hour;
  final int minute;
  final String timeLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  const _ReminderSetting({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.timeLabel,
    required this.onToggle,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ON/OFF トグル
        SwitchListTile(
          value: enabled,
          activeColor: AppColors.theme,
          contentPadding: EdgeInsets.zero,
          onChanged: onToggle,
          title: Text(
            AppStrings.habitReminderEnabledLabel,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            enabled
                ? AppStrings.habitReminderEnabledDesc
                : AppStrings.habitReminderDisabledDesc,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          secondary: Icon(
            enabled ? Icons.notifications_active : Icons.notifications_off,
            color: enabled ? AppColors.theme : Colors.grey,
          ),
        ),

        // 時刻選択（ONのとき表示）
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: enabled
              ? Column(
                  children: [
                    const Divider(height: 8),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        Icon(Icons.access_time,
                            size: 18, color: AppColors.themeDark),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.habitReminderTimeLabel,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        // 時刻表示ボタン
                        InkWell(
                          onTap: onPickTime,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.themeLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.themeBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeLabel,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.themeDark,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.edit,
                                    size: 16, color: AppColors.theme),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// 復帰促進通知設定ウィジェット
// ══════════════════════════════════════════════════════════
class _ComebackSetting extends StatelessWidget {
  final bool enabled;
  final HabitComebackPeriod period;
  final ValueChanged<bool> onToggle;
  final ValueChanged<HabitComebackPeriod> onPeriodChanged;

  const _ComebackSetting({
    required this.enabled,
    required this.period,
    required this.onToggle,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ON/OFF トグル
        SwitchListTile(
          value: enabled,
          activeColor: AppColors.theme,
          contentPadding: EdgeInsets.zero,
          onChanged: onToggle,
          title: Text(
            AppStrings.habitComebackEnabledLabel,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            enabled
                ? AppStrings.habitComebackEnabledDesc
                : AppStrings.habitComebackDisabledDesc,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          secondary: Icon(
            enabled ? Icons.person_add_alt_1 : Icons.person_off_outlined,
            color: enabled ? AppColors.theme : Colors.grey,
          ),
        ),

        // 期間選択（ONのとき表示）
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: enabled
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 8),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        Icon(Icons.hourglass_empty,
                            size: 18, color: AppColors.themeDark),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.habitComebackPeriodLabel,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 3択セグメントボタン
                    Row(
                      children: HabitComebackPeriod.values.map((p) {
                        final selected = period == p;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: p != HabitComebackPeriod.values.last
                                    ? 8
                                    : 0),
                            child: GestureDetector(
                              onTap: () => onPeriodChanged(p),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.theme
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.theme
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  p.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: selected
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// 設定セクションカード
// ══════════════════════════════════════════════════════════
class _SettingsSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSectionCard({required this.title, required this.child});

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
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 分数設定ウィジェット（作業時間・休憩時間共用）
// ══════════════════════════════════════════════════════════
class _MinutesSetting extends StatelessWidget {
  final int minutes;
  final int minMinutes;
  final int maxMinutes;
  final ValueChanged<int> onChanged;

  static const int _step = 1;

  const _MinutesSetting({
    required this.minutes,
    required this.minMinutes,
    required this.maxMinutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HoldRepeatIconButton(
              onStep: minutes > minMinutes
                  ? () => onChanged(minutes - _step)
                  : null,
              icon: Icons.remove_circle_outline,
              color: AppColors.theme,
              iconSize: 32,
            ),
            const SizedBox(width: 12),
            Text(
              '$minutes 分',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: AppColors.theme,
              ),
            ),
            const SizedBox(width: 12),
            HoldRepeatIconButton(
              onStep: minutes < maxMinutes
                  ? () => onChanged(minutes + _step)
                  : null,
              icon: Icons.add_circle_outline,
              color: AppColors.theme,
              iconSize: 32,
            ),
          ],
        ),
        Slider(
          value: minutes.toDouble(),
          min: minMinutes.toDouble(),
          max: maxMinutes.toDouble(),
          divisions: maxMinutes - minMinutes,
          activeColor: AppColors.theme,
          label: '$minutes 分',
          onChanged: (v) => onChanged(v.round()),
        ),
        Text(
          '$minMinutes 分〜$maxMinutes 分',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
