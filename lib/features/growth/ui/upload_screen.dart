import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../state/growth_provider.dart';

// ══════════════════════════════════════════════════════════
// イラストを追加画面
//
// 「戻る」はAppBarの標準戻るボタンで対応。
//
// 「カメラで追加」（撮影）・「ファイルで追加」（ギャラリー選択）は
// どちらも GrowthNotifier（growthProvider）の pickImageFromCamera /
// pickImageFromGallery を呼ぶだけで、この時点では保存（Hive・ファイル
// への書き込み）を行わない。選択結果はプレビューエリアに表示し、
// 「確定」ボタンをタップした時点で初めて GrowthNotifier.confirmUpload
// を呼んで実際の保存処理を行う（picker種別が異なるだけで、以降の
// 保存フロー・エラーハンドリングは共通）。
//
// プレビューエリア：
//   ・画像未選択時はプレースホルダー（アイコン＋文言）を表示する。
//   ・カメラ／ファイルどちらかで画像を選ぶとプレビューに反映され、
//     確定ボタンが活性化する。再度選び直すとプレビューが上書きされる。
//
// 画面レイアウト（上から順）：
//   プレビューエリア → 「ファイルで追加」「カメラで追加」ボタン
//   （左右配置） → 所要時間入力 → 確定ボタン
//
// 所要時間（任意）入力：
//   ・半角数字のみ許可（空欄も可）。確定ボタン押下時にバリデーションし、
//     半角数字以外が入力されていればエラーを表示して処理を中断する。
//   ・入力値（分）はそのままGrowthRecord.durationMinとして保存され、
//     保存ファイル名にも反映される（例：2026-06-01-2枚目-3分.png）。
//
// 保持上限枚数（GrowthConfig.maxRecordCount）：
//   ・上限を超えてアップロードすると最古の1件が自動削除される。
//   ・「ちょうど上限に到達したアップロード」の場合のみ、完了画面に
//     特別メッセージを表示する（isMaxCountReached をルートへ渡す）。
// ══════════════════════════════════════════════════════════
class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final TextEditingController _durationController = TextEditingController();

  /// プレビュー中の画像（未選択時は null）。確定ボタンの活性条件でもある。
  XFile? _pickedImage;

  bool _isPickingCamera = false;
  bool _isPickingGallery = false;
  bool _isUploading = false;

  bool get _isBusy => _isPickingCamera || _isPickingGallery || _isUploading;

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  /// 所要時間欄が半角数字のみ（または空欄）かどうかを判定する。
  /// 空欄は「未入力」として許可する。
  bool _isDurationInputValid(String input) {
    if (input.isEmpty) return true;
    return RegExp(r'^[0-9]+$').hasMatch(input);
  }

  void _showDurationInvalidError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.growthDurationInvalidError)),
    );
  }

  // ── カメラで撮影 → プレビューへ反映（保存はまだ行わない） ──
  Future<void> _onCameraTap() async {
    setState(() => _isPickingCamera = true);
    try {
      final picked =
          await ref.read(growthProvider.notifier).pickImageFromCamera();
      if (!mounted) return;
      if (picked != null) {
        setState(() => _pickedImage = picked);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.growthCameraError)),
      );
    } finally {
      if (mounted) setState(() => _isPickingCamera = false);
    }
  }

  // ── ギャラリーから選択 → プレビューへ反映（保存はまだ行わない） ──
  Future<void> _onFileUploadTap() async {
    setState(() => _isPickingGallery = true);
    try {
      final picked =
          await ref.read(growthProvider.notifier).pickImageFromGallery();
      if (!mounted) return;
      if (picked != null) {
        setState(() => _pickedImage = picked);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.growthGalleryError)),
      );
    } finally {
      if (mounted) setState(() => _isPickingGallery = false);
    }
  }

  // ── 確定：プレビュー中の画像を実際に保存する ──
  Future<void> _onConfirmTap() async {
    final picked = _pickedImage;
    if (picked == null || _isBusy) return;

    final input = _durationController.text.trim();
    if (!_isDurationInputValid(input)) {
      _showDurationInvalidError();
      return;
    }
    final durationMin = input.isEmpty ? null : int.parse(input);

    setState(() => _isUploading = true);
    try {
      final uploadResult = await ref
          .read(growthProvider.notifier)
          .confirmUpload(picked, durationMin: durationMin);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        AppRouter.growthUploadComplete(
          isMaxCountReached: uploadResult.isMaxCountReached,
          isStreakMilestoneReached: uploadResult.isStreakMilestoneReached,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.growthConfirmError)),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.growthUploadScreenTitle),
        backgroundColor: AppColors.theme,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── プレビューエリア ──
              _PreviewArea(image: _pickedImage),
              const SizedBox(height: 20),

              // ── ファイルで追加／カメラで追加（左右配置） ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.theme,
                        side: const BorderSide(color: AppColors.theme),
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isBusy ? null : _onFileUploadTap,
                      icon: _isPickingGallery
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.theme),
                              ),
                            )
                          : const Icon(Icons.folder_open_outlined),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppStrings.growthFileUploadButton,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.theme,
                        side: const BorderSide(color: AppColors.theme),
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isBusy ? null : _onCameraTap,
                      icon: _isPickingCamera
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.theme),
                              ),
                            )
                          : const Icon(Icons.photo_camera_outlined),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppStrings.growthCameraUploadButton,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 所要時間（任意） ──
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppStrings.growthDurationInputLabel,
                  suffixText: AppStrings.growthDurationInputUnit,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.theme, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── 確定：プレビュー中の画像が無い間は非活性 ──
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.theme,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    (_pickedImage == null || _isBusy) ? null : _onConfirmTap,
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        AppStrings.growthConfirmButton,
                        style: const TextStyle(fontSize: 16),
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
// プレビューエリア
//
// 画像未選択時はプレースホルダー（アイコン＋文言）、選択済みの間は
// Image.file で実ファイルを表示する。カメラ撮影／ギャラリー選択の
// どちらでも同じ見た目を使う。
// ══════════════════════════════════════════════════════════
class _PreviewArea extends StatelessWidget {
  final XFile? image;

  const _PreviewArea({required this.image});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.themeLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.themeBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: image == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined,
                        size: 48, color: AppColors.themeDark.withAlpha(120)),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.growthPreviewPlaceholder,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.themeDark.withAlpha(160),
                      ),
                    ),
                  ],
                ),
              )
            : Image.file(
                File(image!.path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
      ),
    );
  }
}
