import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../../growth/state/growth_provider.dart';

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
//      実フラグを直接ON/OFFする。この項目自体はメンテナンス画面
//      導入前から存在する“実データ”であり、初期値は「未到達
//      （false）」＝リリース直後の状態と同じ扱いにしている）
//
// 今後の項目（GrowthConfig.maxRecordCount 等の数値コンフィグ）を
// 追加する際は、_MaintenanceState に編集用フィールドを増やし、
// _decide() / _resetToDefault() にそれぞれの反映・初期化処理を
// 追記していく。
// ══════════════════════════════════════════════════════════
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() =>
      _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  // ── 成長記録：保持上限到達フラグ（画面上の未反映の選択値）──
  // リリース時の初期値 = false（未到達）。
  // 実機の現在値を確認しやすいよう、画面を開いた時点では実際の
  // 現在値を初期表示する（決定を押すまでは実フラグには影響しない）。
  late bool _maxCountReached;

  @override
  void initState() {
    super.initState();
    _maxCountReached = ref.read(growthMaxCountReachedProvider);
  }

  Future<void> _decide() async {
    await ref
        .read(growthProvider.notifier)
        .setMaxCountReachedFlagForDebug(_maxCountReached);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _maxCountReached
              ? AppStrings.growthDebugMaxCountFlagOnDoneMessage
              : AppStrings.growthDebugMaxCountFlagOffDoneMessage,
        ),
      ),
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

    setState(() => _maxCountReached = false);
    await ref
        .read(growthProvider.notifier)
        .setMaxCountReachedFlagForDebug(false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.maintenanceResetDone)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  child: SwitchListTile(
                    value: _maxCountReached,
                    activeColor: AppColors.theme,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _maxCountReached = v),
                    title: Text(
                      AppStrings.maintenanceMaxCountReachedLabel,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      _maxCountReached
                          ? AppStrings.maintenanceMaxCountReachedOnDesc
                          : AppStrings.maintenanceMaxCountReachedOffDesc,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
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
