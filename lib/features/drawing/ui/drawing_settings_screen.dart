import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/extensions/int_ext.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../../../shared/components/hold_repeat_icon_button.dart';
import '../../../core/config/drawing_config.dart';
import '../domain/drawing_model.dart';
import '../domain/drawing_settings.dart';
import '../state/drawing_settings_controller.dart';

// ══════════════════════════════════════════════════════════
// X秒ドローイング 設定画面
// ══════════════════════════════════════════════════════════
class DrawingSettingsScreen extends StatefulWidget {
  const DrawingSettingsScreen({super.key});

  @override
  State<DrawingSettingsScreen> createState() => _DrawingSettingsScreenState();
}

class _DrawingSettingsScreenState extends State<DrawingSettingsScreen> {
  List<DrawingModel> _allModels = [];
  List<DrawingCategoryDef> _categories = [];
  Set<String> _selectedCategories = {};

  int _durationSec = DrawingSettingsController.defaultDurationSec;
  bool _loop = DrawingSettingsController.defaultLoop;
  bool _shuffle = DrawingSettingsController.defaultShuffle;
  int _maxWorkTimeSec = DrawingSettingsController.defaultMaxWorkTimeSec;

  bool get _allCategoriesSelected =>
      _selectedCategories.length == _categories.length;

  bool get _canStart => _selectedCategories.isNotEmpty;

  List<DrawingModel> get _selectedModels => _allModels
      .where((m) => _selectedCategories.contains(m.categoryId))
      .toList();

  @override
  void initState() {
    super.initState();
    _loadModelsAndSettings();
  }

  Future<void> _loadModelsAndSettings() async {
    try {
      final results = await Future.wait([
        DrawingModelLoader.load(),
        DrawingSettingsController.load(),
      ]);

      if (!mounted) return;

      final models = results[0] as List<DrawingModel>;
      final saved = results[1] as SavedDrawingSettings?;

      setState(() {
        _allModels = models;
        _categories = DrawingModelLoader.categories(models);

        if (saved != null) {
          _durationSec = saved.durationSec;
          _loop = saved.loop;
          _shuffle = saved.shuffle;
          _maxWorkTimeSec = saved.maxWorkTimeSec;
          final validCategoryIds =
              _categories.map((c) => c.id).toSet();
          final validCategories =
              saved.selectedCategories.where(validCategoryIds.contains).toSet();
          _selectedCategories = validCategories.isNotEmpty
              ? validCategories
              : _categories.map((c) => c.id).toSet();
        } else {
          _selectedCategories = _categories.map((c) => c.id).toSet();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('読み込みに失敗しました: $e')),
      );
    }
  }

  void _toggleAllCategories(bool select) {
    setState(() {
      _selectedCategories = select ? _categories.map((c) => c.id).toSet() : {};
    });
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  Future<void> _saveSettings() async {
    await DrawingSettingsController.save(
      durationSec: _durationSec,
      loop: _loop,
      shuffle: _shuffle,
      selectedCategories: _selectedCategories.toList(),
      maxWorkTimeSec: _maxWorkTimeSec,
    );
  }

  Future<void> _onSaveOnly() async {
    await _saveSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.drawingSettingsSaved),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onSaveAndStart() async {
    await _saveSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.drawingSettingsSaved),
        duration: const Duration(seconds: 2),
      ),
    );

    final settings = DrawingSettings(
      durationSec: _durationSec,
      selectedModels: _selectedModels,
      loop: _loop,
      shuffle: _shuffle,
      maxWorkTimeSec: _maxWorkTimeSec,
    );
    Navigator.push(context, AppRouter.drawingMain(settings));
  }

  Future<void> _onResetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.drawingSettingsResetTitle),
        content: Text(AppStrings.drawingSettingsResetMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.dialogCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.dialogReset),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await DrawingSettingsController.clear();
    if (!mounted) return;

    setState(() {
      _durationSec = DrawingSettingsController.defaultDurationSec;
      _loop = DrawingSettingsController.defaultLoop;
      _shuffle = DrawingSettingsController.defaultShuffle;
      _maxWorkTimeSec = DrawingSettingsController.defaultMaxWorkTimeSec;
      _selectedCategories = _categories.map((c) => c.id).toSet();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.drawingSettingsReset)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.drawingSettingsTitle,
        backgroundColor: AppColors.theme,
        actions: [
          IconButton(
            tooltip: AppStrings.drawingSettingsResetTitle,
            icon: const Icon(Icons.restart_alt),
            onPressed: _allModels.isEmpty ? null : _onResetToDefaults,
          ),
        ],
      ),
      body: _allModels.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final double outerPad =
                    (constraints.maxWidth * AppValues.outerPadRatio)
                        .clamp(AppValues.outerPadMin, AppValues.outerPadMax);

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    outerPad,
                    AppValues.settingsScrollPadding,
                    outerPad,
                    AppValues.settingsScrollPadding +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    // ── 切り替え時間 ──────────────────────────
                    _SettingsSectionCard(
                      title: AppStrings.drawingSettingsDurationTitle,
                      child: _DurationSetting(
                        durationSec: _durationSec,
                        onDecrement: _durationSec > AppValues.drawingDurationMinSec
                            ? () => setState(() =>
                                _durationSec -= AppValues.drawingDurationStepSec)
                            : null,
                        onIncrement: _durationSec < AppValues.drawingDurationMaxSec
                            ? () => setState(() =>
                                _durationSec += AppValues.drawingDurationStepSec)
                            : null,
                        onSliderChanged: (v) => setState(() =>
                            _durationSec = (v.round() ~/
                                    AppValues.drawingDurationStepSec) *
                                AppValues.drawingDurationStepSec),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── ループ設定 ────────────────────────────
                    _SettingsSectionCard(
                      title: AppStrings.drawingSettingsLoopTitle,
                      child: SwitchListTile(
                        value: _loop,
                        activeColor: AppColors.theme,
                        onChanged: (v) => setState(() => _loop = v),
                        title: Text(
                          _loop ? AppStrings.drawingLoopOnTitle : AppStrings.drawingLoopOffTitle,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _loop
                              ? AppStrings.drawingLoopOnDesc
                              : AppStrings.drawingLoopOffDesc,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                          overflow: TextOverflow.visible,
                        ),
                        secondary: Icon(
                          _loop ? Icons.repeat : Icons.trending_flat,
                          color: _loop ? AppColors.theme : Colors.grey,
                        ),
                        isThreeLine: true,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 再生順序 ──────────────────────────────
                    _SettingsSectionCard(
                      title: AppStrings.drawingSettingsShuffleTitle,
                      child: SwitchListTile(
                        value: _shuffle,
                        activeColor: AppColors.theme,
                        onChanged: (v) => setState(() => _shuffle = v),
                        title: Text(
                          _shuffle
                              ? AppStrings.drawingRandomOrder
                              : AppStrings.drawingRegisteredOrder,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _shuffle
                              ? AppStrings.drawingShuffleOnDesc
                              : AppStrings.drawingShuffleOffDesc,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                          overflow: TextOverflow.visible,
                        ),
                        secondary: Icon(
                          _shuffle ? Icons.shuffle : Icons.sort,
                          color: _shuffle ? AppColors.theme : Colors.grey,
                        ),
                        isThreeLine: true,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 最大作業時間 ──────────────────────────
                    _SettingsSectionCard(
                      title: AppStrings.drawingSettingsMaxTimeTitle,
                      child: _MaxWorkTimeSetting(
                        maxWorkTimeSec: _maxWorkTimeSec,
                        onChanged: (v) =>
                            setState(() => _maxWorkTimeSec = v),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── カテゴリ選択 ──────────────────────────
                    _SettingsSectionCard(
                      title: AppStrings.drawingSettingsCategoryTitle,
                      child: _CategorySelector(
                        categories: _categories,
                        selectedCategories: _selectedCategories,
                        allModels: _allModels,
                        allCategoriesSelected: _allCategoriesSelected,
                        onToggleAll: _toggleAllCategories,
                        onToggleCategory: _toggleCategory,
                        selectedModelsCount: _selectedModels.length,
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (!_canStart)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          AppStrings.drawingSettingsCategoryWarning,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),

                    // ── 保存 ／ 保存して開始 ──────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.theme,
                              side: const BorderSide(color: AppColors.theme),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _onSaveOnly,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              AppStrings.drawingSettingsSaveButton,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _canStart ? AppColors.theme : Colors.grey,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _canStart ? _onSaveAndStart : null,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(
                              AppStrings.drawingSettingsSaveAndStartButton,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ── 設定セクションカード ────────────────────────────────────
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
            Text(
              title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ── 最大作業時間設定ウィジェット ────────────────────────────
class _MaxWorkTimeSetting extends StatelessWidget {
  /// 最大作業時間（秒）。0 = 無制限。
  final int maxWorkTimeSec;
  final ValueChanged<int> onChanged;

  const _MaxWorkTimeSetting({
    required this.maxWorkTimeSec,
    required this.onChanged,
  });

  bool get _isUnlimited =>
      maxWorkTimeSec == AppValues.drawingMaxWorkTimeUnlimited;

  int get _minutes => maxWorkTimeSec ~/ 60;

  String get _displayLabel => _isUnlimited
      ? AppStrings.drawingSettingsMaxTimeUnlimited
      : '$_minutes 分';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 無制限トグル
        SwitchListTile(
          value: _isUnlimited,
          activeColor: AppColors.theme,
          onChanged: (v) => onChanged(
              v ? AppValues.drawingMaxWorkTimeUnlimited : 10 * 60),
          title: const Text(AppStrings.drawingSettingsMaxTimeUnlimited,
              style: TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
          subtitle: Text(
            _isUnlimited ? AppStrings.drawingMaxTimeUnlimitedDesc : AppStrings.drawingMaxTimeLimitedDesc,
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade500),
            overflow: TextOverflow.visible,
          ),
          secondary: Icon(Icons.all_inclusive,
              color: _isUnlimited ? AppColors.theme : Colors.grey),
          isThreeLine: true,
        ),

        // 時間選択（無制限OFF時のみ表示）
        if (!_isUnlimited) ...[
          const Divider(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HoldRepeatIconButton(
                onStep: _minutes > AppValues.drawingMaxWorkTimeMinMin
                    ? () => onChanged(
                        (_minutes - AppValues.drawingMaxWorkTimeStepMin) *
                            60)
                    : null,
                icon: Icons.remove_circle_outline,
                color: AppColors.theme,
                iconSize: 32,
              ),
              const SizedBox(width: 12),
              Text(
                _displayLabel,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.theme,
                ),
              ),
              const SizedBox(width: 12),
              HoldRepeatIconButton(
                onStep: _minutes < AppValues.drawingMaxWorkTimeMaxMin
                    ? () => onChanged(
                        (_minutes + AppValues.drawingMaxWorkTimeStepMin) *
                            60)
                    : null,
                icon: Icons.add_circle_outline,
                color: AppColors.theme,
                iconSize: 32,
              ),
            ],
          ),
          Slider(
            value: _minutes.toDouble(),
            min: AppValues.drawingMaxWorkTimeMinMin.toDouble(),
            max: AppValues.drawingMaxWorkTimeMaxMin.toDouble(),
            divisions: AppValues.drawingMaxWorkTimeMaxMin -
                AppValues.drawingMaxWorkTimeMinMin,
            activeColor: AppColors.theme,
            label: _displayLabel,
            onChanged: (v) =>
                onChanged(v.round() * 60),
          ),
          Text(
            '${AppValues.drawingMaxWorkTimeMinMin} 分〜'
            '${AppValues.drawingMaxWorkTimeMaxMin} 分'
            '（${AppValues.drawingMaxWorkTimeStepMin} 分単位）',
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

// ── 切り替え時間設定ウィジェット ────────────────────────────
class _DurationSetting extends StatelessWidget {
  final int durationSec;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final ValueChanged<double> onSliderChanged;

  const _DurationSetting({
    required this.durationSec,
    required this.onDecrement,
    required this.onIncrement,
    required this.onSliderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HoldRepeatIconButton(
              onStep: onDecrement,
              icon: Icons.remove_circle_outline,
              color: AppColors.theme,
              iconSize: 32,
            ),
            const SizedBox(width: 12),
            Text(
              durationSec.toDisplayDuration(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.theme,
              ),
            ),
            const SizedBox(width: 12),
            HoldRepeatIconButton(
              onStep: onIncrement,
              icon: Icons.add_circle_outline,
              color: AppColors.theme,
              iconSize: 32,
            ),
          ],
        ),
        Slider(
          value: durationSec.toDouble(),
          min: AppValues.drawingDurationMinSec.toDouble(),
          max: AppValues.drawingDurationMaxSec.toDouble(),
          divisions: (AppValues.drawingDurationMaxSec -
                  AppValues.drawingDurationMinSec) ~/
              AppValues.drawingDurationStepSec,
          activeColor: AppColors.theme,
          label: durationSec.toDisplayDuration(),
          onChanged: onSliderChanged,
        ),
        Text(
          '${AppValues.drawingDurationMinSec.toDisplayDuration()}〜'
          '${AppValues.drawingDurationMaxSec.toDisplayDuration()}'
          '（${AppValues.drawingDurationStepSec.toDisplayDuration()}単位）',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

// ── カテゴリ選択ウィジェット ────────────────────────────────
class _CategorySelector extends StatelessWidget {
  final List<DrawingCategoryDef> categories;
  final Set<String> selectedCategories; // カテゴリIDのSet
  final List<DrawingModel> allModels;
  final bool allCategoriesSelected;
  final ValueChanged<bool> onToggleAll;
  final ValueChanged<String> onToggleCategory;
  final int selectedModelsCount;

  const _CategorySelector({
    required this.categories,
    required this.selectedCategories,
    required this.allModels,
    required this.allCategoriesSelected,
    required this.onToggleAll,
    required this.onToggleCategory,
    required this.selectedModelsCount,
  });

  /// 全選択 → true / 部分選択 → null（インジケーター） / 全解除 → false
  bool? get _checkboxValue {
    if (selectedCategories.isEmpty) return false;
    if (allCategoriesSelected) return true;
    return null; // 部分選択
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _checkboxValue,
              tristate: true,
              activeColor: AppColors.theme,
              // null（部分選択）をタップ → 全選択、それ以外 → 現在値を反転
              onChanged: (_) => onToggleAll(!allCategoriesSelected),
            ),
            Text(
              AppStrings.drawingSettingsSelectAll,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${selectedCategories.length} / ${categories.length} カテゴリ',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.right,
                ),
                Text(
                  '（$selectedModelsCount 枚）',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ],
        ),
        const Divider(),
        ...categories.map((categoryDef) {
          final selected = selectedCategories.contains(categoryDef.id);
          final count =
              allModels.where((m) => m.categoryId == categoryDef.id).length;
          return CheckboxListTile(
            value: selected,
            activeColor: AppColors.theme,
            title: Text(categoryDef.name),
            subtitle: Text('$count 枚', style: const TextStyle(fontSize: 11)),
            secondary: Icon(
              Icons.folder_outlined,
              color: selected ? AppColors.theme : Colors.grey,
            ),
            onChanged: (_) => onToggleCategory(categoryDef.id),
          );
        }),
      ],
    );
  }
}
