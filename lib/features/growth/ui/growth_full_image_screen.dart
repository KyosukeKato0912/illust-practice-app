import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../domain/growth_record.dart';

// ══════════════════════════════════════════════════════════
// 成長記録 拡大表示画面
//
// shared/patterns/full_image_screen.dart（X秒ドローイング用）と
// 同じ操作感（ピンチ拡大縮小・前へ/次へボタン）を成長記録向けに
// 実装したもの。
//
// ⚠ full_image_screen.dart はDrawingModel専用の実装になっており
//   （ファイル内の注意書き参照）、GrowthRecordとはデータ構造
//   （カテゴリ/作者/頭身ペア　vs　日付/連番/所要時間、
//   Image.asset vs Image.file）が大きく異なるため、
//   共通化はせず本画面として個別実装する。
//   将来的に両者を共通化する場合は、full_image_screen.dart側の
//   注意書きにある DisplayableAsset 抽象化を先に行うこと。
// ══════════════════════════════════════════════════════════
class GrowthFullImageScreen extends StatefulWidget {
  /// 最初に表示するレコード
  final GrowthRecord initialRecord;

  /// 前へ/次への移動対象となる一覧（GrowthMainScreen表示中の並び順）
  final List<GrowthRecord> allRecords;

  const GrowthFullImageScreen({
    super.key,
    required this.initialRecord,
    required this.allRecords,
  });

  @override
  State<GrowthFullImageScreen> createState() => _GrowthFullImageScreenState();
}

class _GrowthFullImageScreenState extends State<GrowthFullImageScreen> {
  late int _currentIndex;

  GrowthRecord get _current => widget.allRecords[_currentIndex];

  bool get _isFirst => _currentIndex <= 0;
  bool get _isLast => _currentIndex >= widget.allRecords.length - 1;

  @override
  void initState() {
    super.initState();
    final idx = widget.allRecords
        .indexWhere((r) => r.id == widget.initialRecord.id);
    _currentIndex = idx != -1 ? idx : 0;
  }

  void _prevRecord() {
    if (_isFirst) return;
    setState(() => _currentIndex--);
  }

  void _nextRecord() {
    if (_isLast) return;
    setState(() => _currentIndex++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.enlargeViewTitle,
        backgroundColor: AppColors.theme,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double outerPad =
              (constraints.maxWidth * AppValues.outerPadRatio)
                  .clamp(AppValues.outerPadMin, AppValues.outerPadMax);

          return Column(
            children: [
              // ── 情報バー（日付・連番・所要時間） ──────────────
              _InfoBar(record: _current, outerPad: outerPad),

              // ── 画像表示エリア ────────────────────────────
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: outerPad),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Image.file(
                      File(_current.imagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── ボタンエリア（前へ／次へ） ───────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(outerPad, 8, outerPad, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _NavButton(
                        icon: Icons.chevron_left,
                        enabled: !_isFirst,
                        onPressed: _prevRecord,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _NavButton(
                        icon: Icons.chevron_right,
                        enabled: !_isLast,
                        onPressed: _nextRecord,
                      ),
                    ),
                  ],
                ),
              ),

              // ── ピンチヒント ────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  outerPad,
                  4,
                  outerPad,
                  AppValues.bottomHintPadding +
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: Text(
                  AppStrings.drawingPinchHint,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── 情報バー ───────────────────────────────────────────────
class _InfoBar extends StatelessWidget {
  final GrowthRecord record;
  final double outerPad;

  const _InfoBar({required this.record, required this.outerPad});

  String get _dateLabel {
    final d = record.date;
    return '${d.year}/${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.theme.withAlpha(20),
      padding: EdgeInsets.fromLTRB(outerPad, 8, outerPad, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 2,
        children: [
          _InfoChip(icon: Icons.event_outlined, label: _dateLabel),
          _InfoChip(
            icon: Icons.confirmation_number_outlined,
            label: '${record.serialNumber}${AppStrings.growthSerialSuffix}',
          ),
          if (record.durationMin != null)
            _InfoChip(
              icon: Icons.timer_outlined,
              label:
                  '${record.durationMin}${AppStrings.growthDurationMinSuffix}',
            ),
        ],
      ),
    );
  }
}

// ── 前へ/次へナビゲーションボタン ─────────────────────────
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? AppColors.theme : Colors.grey.shade300,
        foregroundColor: enabled ? Colors.white : Colors.grey.shade500,
        minimumSize: const Size(0, 44),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: enabled ? onPressed : null,
      child: Icon(icon, size: 28),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.theme.withAlpha(180)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.theme,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
