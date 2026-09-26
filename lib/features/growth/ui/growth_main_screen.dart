import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/growth_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/growth_pdf_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../domain/growth_record.dart';
import '../state/growth_provider.dart';

// ══════════════════════════════════════════════════════════
// 成長記録 メイン画面
//
// 登録済み画像のサムネグリッドとアップロードボタンを表示する。
// レイアウト・配色は features/drawing/ui/model_list_screen.dart に
// 準拠し、機能間でのUI一貫性を保つ。
//
// データは growthProvider（GrowthNotifier）経由でHiveから取得する。
// サムネを長押しすると選択モードに入り、指を離さずドラッグすると
// 長押し開始位置〜現在位置の範囲（一覧の並び順）を連続選択できる。
// 選択後はAppBarの削除ボタンでまとめて削除できる。
//
// 絞込（日付範囲）: model_list_screen.dart の絞込UI（検索エリア・
// 件数＋クリア行・空状態の出し分け）に準拠。選択中の日付範囲に
// 一致するレコードのみをグリッドに表示する。長押しドラッグ選択は
// 表示中（フィルタ後）のレコード順に対して行われる。
// フルイメージ表示（AppRouter.growthFullImage）はmodel_list_screen
// に合わせ、フィルタの影響を受けない全レコードをスワイプ対象として渡す。
//
// PDF書き出し: 下部の「イラストを保存」ボタンの右隣に配置したボタンから、
// 絞込の影響を受けない全レコードを GrowthPdfService でPDF化し、
// file_picker (FilePicker.platform.saveFile) 経由でOSの保存ダイアログから保存する。
// このボタンは保持上限到達フラグ（growthMaxCountReachedProvider）が
// 立っている間のみ表示する（上限に一度も到達していない間は非表示）。
//
// SNS投稿: 「イラストを追加」「イラストを保存」の間に配置。
// 選択中の画像を share_plus の共有シート経由で渡す（本アプリからXへ
// APIで直接投稿するのではなく、共有シートでXアプリを選ぶとXの投稿画面に
// 画像・文言が渡った状態で遷移し、実際の投稿操作はX側で行う方式）。
// 有効化条件は選択中の画像が1件以上4件以下の場合のみ
// （Xの1投稿に添付できる画像枚数の上限が4枚のため）。
// 0件、または5件以上選択している間はボタンを無効化する。
//
//   SNS投稿等は次のステップで対応する。
//
// ⚠ 範囲選択の座標→インデックス変換は、GridViewのレイアウト定数
//   （crossAxisSpacing/mainAxisSpacing/childAspectRatio等）を
//   _GrowthThumbnailGrid 側と手動で一致させる方式（幾何計算）。
//   両者を変更する際は必ずセットで直すこと。
//   また、画面外（未スクロール領域）へのドラッグ時の自動スクロールは
//   現フェーズ未対応（表示中の範囲内でのドラッグ選択のみ）。
// ══════════════════════════════════════════════════════════
class GrowthMainScreen extends ConsumerStatefulWidget {
  const GrowthMainScreen({super.key});

  @override
  ConsumerState<GrowthMainScreen> createState() => _GrowthMainScreenState();
}

class _GrowthMainScreenState extends ConsumerState<GrowthMainScreen> {
  final Set<String> _selectedIds = {};
  final ScrollController _scrollController = ScrollController();

  /// Xへの1投稿で添付できる画像枚数の上限（1〜4枚）。
  /// SNS投稿ボタンの有効化条件（1件以上4件以下選択中）に使用する。
  static const int _snsShareMaxCount = 4;

  /// ドラッグ選択の起点インデックス（長押し中のみ非null）
  int? _dragAnchorIndex;

  bool _isDownloading = false;

  /// SNS共有シート起動中フラグ（多重タップ防止・ローディング表示用）
  bool _isSharing = false;

  /// PDF生成中フラグ（多重タップ防止・ローディング表示用）
  bool _isGeneratingPdf = false;

  /// 絞込中の日付範囲（null = 絞込なし）
  DateTimeRange? _selectedDateRange;

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  /// SNS投稿ボタンの有効化条件：選択中が1件以上4件以下
  /// （Xの1投稿に添付できる画像枚数の上限が4枚のため）
  bool get _canShareToSns =>
      _selectedIds.isNotEmpty && _selectedIds.length <= _snsShareMaxCount;

  bool get _hasFilter => _selectedDateRange != null;

  // ── 日付範囲での絞込 ─────────────────────────────────────
  List<GrowthRecord> _applyFilter(List<GrowthRecord> all) {
    final range = _selectedDateRange;
    if (range == null) return all;
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return all.where((record) {
      final d = DateTime(record.date.year, record.date.month, record.date.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
  }

  void _clearFilter() {
    setState(() => _selectedDateRange = null);
  }

  Future<void> _onPickDateRange(BuildContext context) async {
    final today = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: AppStrings.growthFilterDateLabel,
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
      setState(() => _selectedDateRange = picked);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedIds.clear();
      _dragAnchorIndex = null;
    });
  }

  void _onUploadTap(BuildContext context) {
    if (_isSelectionMode) {
      setState(() {
        _selectedIds.clear();
        _dragAnchorIndex = null;
      });
    }
    Navigator.push(context, AppRouter.growthUpload());
  }

  /// 【検証用】保持上限到達フラグをON/OFF切り替える。
  /// GrowthConfig.showDebugMaxCountReachedToggleButton が false の場合、
  /// このボタン自体が表示されないため呼ばれない。
  Future<void> _onDebugToggleMaxCountFlagTap(BuildContext context) async {
    await ref.read(growthProvider.notifier).toggleMaxCountReachedFlagForDebug();
    if (!context.mounted) return;
    final nowReached = ref.read(growthMaxCountReachedProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowReached
              ? AppStrings.growthDebugMaxCountFlagOnDoneMessage
              : AppStrings.growthDebugMaxCountFlagOffDoneMessage,
        ),
      ),
    );
  }

  Future<void> _onDownloadTap(BuildContext context) async {
    if (_selectedIds.isEmpty || _isDownloading) return;
    final ids = _selectedIds.toList();
    setState(() {
      _isDownloading = true;
      _selectedIds.clear();
      _dragAnchorIndex = null;
    });
    try {
      final successCount =
          await ref.read(growthProvider.notifier).downloadRecords(ids);
      if (!mounted) return;
      final failureCount = ids.length - successCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failureCount > 0
                ? AppStrings.growthDownloadFailure
                : '$successCount${AppStrings.growthDownloadSuccessSuffix}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ── SNS投稿（選択中の画像を共有シート経由でXなどへ渡す） ────
  // 実際の投稿操作はX側アプリで行う（本アプリからは共有シートを開き、
  // 選択画像とハッシュタグ文言を渡すところまでを担当する）。
  // 選択状態はここでは解除しない（共有をキャンセルした場合に
  // 選び直さずに再度共有できるようにするため）。
  Future<void> _onSnsShareTap(
    BuildContext context,
    List<GrowthRecord> records,
  ) async {
    if (!_canShareToSns || _isSharing) return;
    final targets = records.where((r) => _selectedIds.contains(r.id)).toList();
    if (targets.isEmpty) return;

    setState(() => _isSharing = true);
    try {
      final files = targets.map((r) => XFile(r.imagePath)).toList();
      await SharePlus.instance.share(
        ShareParams(files: files, text: AppStrings.growthSnsShareText),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.growthSnsShareError)),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _onDeleteTap(BuildContext context) async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.growthDeleteDialogTitle),
        content:
            Text('$count${AppStrings.growthDeleteDialogMessageSuffix}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.growthDeleteDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              AppStrings.growthDeleteDialogConfirm,
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ids = _selectedIds.toList();
    setState(() {
      _selectedIds.clear();
      _dragAnchorIndex = null;
    });
    await ref.read(growthProvider.notifier).deleteRecords(ids);
  }

  // ── PDF書き出し（絞込の影響を受けない全件を対象） ─────────
  Future<void> _onPdfTap(
    BuildContext context,
    List<GrowthRecord> records,
  ) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.growthPdfEmptyError)),
      );
      return;
    }
    if (_isGeneratingPdf) return;

    // タップした時点で「NEW」既読にする（生成の成否は問わない）
    ref.read(growthPdfNewBadgeSeenProvider.notifier).markSeen();

    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await GrowthPdfService.build(records);
      if (!mounted) return;
      // 共有シートではなくOSの保存ダイアログで直接保存する。
      // モバイルではbytesを渡すとプラグイン側が選択先に書き込みまで行う。
      await FilePicker.platform.saveFile(
        fileName: GrowthPdfService.buildFileName(DateTime.now()),
        // 拡張子・MIMEタイプを明示しないと、同名保存時にAndroid側が
        // 「.pdf」を拡張子として認識できず、末尾にそのまま
        // 「(1)」を付け足してしまい開けなくなる（正しくは拡張子の前に
        // 付与されるべき）。type/allowedExtensionsで拡張子を明示することで
        // 保存先アプリ側が名前の重複を拡張子の前で解決するようになる。
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
    } catch (e, st) {
      // 原因調査用の一時ログ（VSCode等のデバッグコンソールに出力）。
      // スマホ側の表示は従来通りSnackBarのみ。
      debugPrint('[GrowthPdfService] PDF生成に失敗しました: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.growthPdfGenerateError)),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ── ローカル座標 → サムネイルのインデックス変換（幾何計算） ──
  // _GrowthThumbnailGrid のGridView設定（列数・余白・アスペクト比）と
  // 必ず一致させること。
  int? _indexFromLocalPosition({
    required Offset localPosition,
    required int crossAxisCount,
    required double outerPad,
    required double gridBoxWidth,
    required int itemCount,
  }) {
    if (itemCount == 0) return null;

    const double crossSpacing = 10;
    const double mainSpacing = 10;
    const double childAspectRatio = 0.75;
    const double topPad = 12;

    final double contentWidth = gridBoxWidth - outerPad * 2;
    final double colWidth =
        (contentWidth - (crossAxisCount - 1) * crossSpacing) /
            crossAxisCount;
    final double rowHeight = colWidth / childAspectRatio;

    final double scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    final double adjX = localPosition.dx - outerPad;
    final double adjY = localPosition.dy - topPad + scrollOffset;

    int col = (adjX / (colWidth + crossSpacing)).floor();
    col = col.clamp(0, crossAxisCount - 1);

    int row = (adjY / (rowHeight + mainSpacing)).floor();
    if (row < 0) row = 0;

    int index = row * crossAxisCount + col;
    if (index < 0) index = 0;
    if (index > itemCount - 1) index = itemCount - 1;
    return index;
  }

  void _onDragSelectStart(
    Offset localPosition,
    int crossAxisCount,
    double outerPad,
    double gridBoxWidth,
    List<GrowthRecord> records,
  ) {
    final index = _indexFromLocalPosition(
      localPosition: localPosition,
      crossAxisCount: crossAxisCount,
      outerPad: outerPad,
      gridBoxWidth: gridBoxWidth,
      itemCount: records.length,
    );
    if (index == null) return;
    setState(() {
      _dragAnchorIndex = index;
      _selectedIds
        ..clear()
        ..add(records[index].id);
    });
  }

  void _onDragSelectUpdate(
    Offset localPosition,
    int crossAxisCount,
    double outerPad,
    double gridBoxWidth,
    List<GrowthRecord> records,
  ) {
    if (_dragAnchorIndex == null) return;
    final index = _indexFromLocalPosition(
      localPosition: localPosition,
      crossAxisCount: crossAxisCount,
      outerPad: outerPad,
      gridBoxWidth: gridBoxWidth,
      itemCount: records.length,
    );
    if (index == null) return;

    final start = _dragAnchorIndex!;
    final lo = start < index ? start : index;
    final hi = start < index ? index : start;

    setState(() {
      _selectedIds
        ..clear()
        ..addAll(records.sublist(lo, hi + 1).map((r) => r.id));
    });
  }

  void _onDragSelectEnd() {
    _dragAnchorIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    final allRecords = ref.watch(growthProvider);
    final records = _applyFilter(allRecords);
    final hasReachedMaxCount = ref.watch(growthMaxCountReachedProvider);
    final hasSeenPdfNewBadge = ref.watch(growthPdfNewBadgeSeenProvider);
    final showPdfNewBadge = hasReachedMaxCount && !hasSeenPdfNewBadge;

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBarWidget(
              title:
                  '${_selectedIds.length}${AppStrings.growthSelectionCountSuffix}',
              backgroundColor: AppColors.theme,
              onBackPressed: _cancelSelection,
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _onDeleteTap(context),
                ),
              ],
            )
          : AppBarWidget(
              title: AppStrings.growthTitle,
              backgroundColor: AppColors.theme,
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double outerPad =
              (constraints.maxWidth * AppValues.outerPadRatio)
                  .clamp(AppValues.outerPadMin, AppValues.outerPadMax);
          final int crossAxisCount = constraints.maxWidth < 600
              ? 2
              : (constraints.maxWidth / 280.0).floor().clamp(2, 8);

          return Column(
            children: [
              // ── 絞込エリア（日付範囲） ───────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(outerPad, 12, outerPad, 4),
                child: _DateRangeFilterField(
                  dateRange: _selectedDateRange,
                  onTap: () => _onPickDateRange(context),
                  onClear: _clearFilter,
                ),
              ),

              // ── 件数 ＋ フィルタークリア ──────────────────
              Padding(
                padding:
                    EdgeInsets.fromLTRB(outerPad, 12, outerPad, 4),
                child: Row(
                  children: [
                    Text(
                      '${records.length} 件',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    if (_hasFilter)
                      TextButton.icon(
                        onPressed: _clearFilter,
                        icon: const Icon(Icons.filter_alt_off, size: 14),
                        label: Text(
                          AppStrings.growthFilterClear,
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.theme,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    if (GrowthConfig.showDebugMaxCountReachedToggleButton) ...[
                      TextButton(
                        onPressed: () =>
                            _onDebugToggleMaxCountFlagTap(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          hasReachedMaxCount
                              ? AppStrings
                                  .growthDebugMaxCountFlagOffButtonLabel
                              : AppStrings
                                  .growthDebugMaxCountFlagOnButtonLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── サムネグリッド（長押し開始→ドラッグで範囲選択） ──
              Expanded(
                child: records.isEmpty
                    ? _GrowthEmptyState(hasFilter: _hasFilter)
                    : GestureDetector(
                        onLongPressStart: (details) => _onDragSelectStart(
                          details.localPosition,
                          crossAxisCount,
                          outerPad,
                          constraints.maxWidth,
                          records,
                        ),
                        onLongPressMoveUpdate: (details) =>
                            _onDragSelectUpdate(
                          details.localPosition,
                          crossAxisCount,
                          outerPad,
                          constraints.maxWidth,
                          records,
                        ),
                        onLongPressEnd: (_) => _onDragSelectEnd(),
                        child: _GrowthThumbnailGrid(
                          records: records,
                          outerPad: outerPad,
                          crossAxisCount: crossAxisCount,
                          scrollController: _scrollController,
                          isSelectionMode: _isSelectionMode,
                          selectedIds: _selectedIds,
                          onToggleSelect: _toggleSelection,
                          onOpenFullImage: (record) => Navigator.push(
                            context,
                            AppRouter.growthFullImage(
                              initialRecord: record,
                              allRecords: allRecords,
                            ),
                          ),
                        ),
                      ),
              ),

              // ── イラストを追加／イラストを保存／PDFでダウンロード ──
              Padding(
                // 20はデザイン上の余白。端末のジェスチャーナビゲーション
                // バー（ホームインジケーター）と重ならないよう、
                // 端末の下部セーフエリア分を追加で確保する。
                padding: EdgeInsets.fromLTRB(
                  outerPad,
                  12,
                  outerPad,
                  AppValues.bottomActionRowPadding +
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.theme,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _onUploadTap(context),
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            size: 20),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppStrings.growthUploadButton,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.theme,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade500,
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (!_canShareToSns || _isSharing)
                            ? null
                            : () => _onSnsShareTap(context, records),
                        icon: _isSharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.ios_share, size: 20),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppStrings.growthSnsButton,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.theme,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade500,
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (_selectedIds.isEmpty || _isDownloading)
                            ? null
                            : () => _onDownloadTap(context),
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.download_outlined, size: 20),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppStrings.growthDownloadButton,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    // ── PDFでダウンロード：保持上限到達フラグが
                    //    立っている間のみ表示 ──
                    if (hasReachedMaxCount) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        // Stack は非配置の子を持たないため、明示的な高さ
                        // （他の3ボタンと同じ52）を与えないと高さ0に潰れる。
                        child: SizedBox(
                          height: 52,
                          child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.theme,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      Colors.grey.shade300,
                                  disabledForegroundColor:
                                      Colors.grey.shade500,
                                  minimumSize: const Size(0, 52),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _isGeneratingPdf
                                    ? null
                                    : () => _onPdfTap(context, allRecords),
                                icon: _isGeneratingPdf
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.picture_as_pdf_outlined,
                                        size: 20),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    AppStrings.growthPdfButton,
                                    maxLines: 1,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ),
                            // ── 「NEW」バッジ：初解禁後、PDFボタンを
                            //    初めてタップするまでの間だけ表示。
                            //    ボタン上部・左寄せに配置する ──
                            if (showPdfNewBadge)
                              Positioned(
                                top: -14,
                                left: 4,
                                child: IgnorePointer(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      AppStrings.growthPdfNewBadge,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// データなし空状態
//
// model_list_screen.dart の _ModelListEmptyState に準拠。
// 絞込中で該当なしの場合は growthEmptyFiltered を表示する。
// ══════════════════════════════════════════════════════════
class _GrowthEmptyState extends StatelessWidget {
  final bool hasFilter;

  const _GrowthEmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_search, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? AppStrings.growthEmptyFiltered
                : AppStrings.growthEmptyState,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 日付絞込フィールド
//
// model_list_screen.dart の _ModelNameSearchField に準拠した
// 見た目（OutlineInputBorder・prefixIcon・isDense）のタップ専用フィールド。
// タップで showDateRangePicker を開き、選択中は範囲をラベル表示、
// suffixIconのクリアボタンで絞込を解除する。
// ══════════════════════════════════════════════════════════
class _DateRangeFilterField extends StatelessWidget {
  final DateTimeRange? dateRange;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateRangeFilterField({
    required this.dateRange,
    required this.onTap,
    required this.onClear,
  });

  String? get _label => dateRange == null
      ? null
      : '${AppDateUtils.formatYMD(dateRange!.start)} 〜 '
          '${AppDateUtils.formatYMD(dateRange!.end)}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        isEmpty: dateRange == null,
        decoration: InputDecoration(
          labelText: AppStrings.growthFilterDateLabel,
          hintText: AppStrings.growthFilterDateHint,
          prefixIcon:
              const Icon(Icons.date_range_outlined, color: AppColors.theme),
          suffixIcon: dateRange != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.theme, width: 2),
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: _label != null
            ? Text(_label!, style: const TextStyle(fontSize: 14))
            : null,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// サムネグリッド
//
// model_list_screen.dart の _ModelThumbnailGrid に準拠
// （余白・アスペクト比を踏襲）。
//
// ⚠ crossAxisCount は親（_GrowthMainScreenState）で計算した値を
//   受け取る。親のドラッグ選択の座標計算と必ず同じ値を使うため、
//   このWidget内では独自に再計算しない。
// ══════════════════════════════════════════════════════════
class _GrowthThumbnailGrid extends StatelessWidget {
  final List<GrowthRecord> records;
  final double outerPad;
  final int crossAxisCount;
  final ScrollController scrollController;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final void Function(String id) onToggleSelect;
  final void Function(GrowthRecord record) onOpenFullImage;

  const _GrowthThumbnailGrid({
    required this.records,
    required this.outerPad,
    required this.crossAxisCount,
    required this.scrollController,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onOpenFullImage,
  });

  @override
  Widget build(BuildContext context) {
    // 情報エリア（日付バッジ・連番・所要時間）の高さを考慮してアスペクト比を調整
    // ⚠ 親の座標計算（_indexFromLocalPosition）と同じ値にすること
    const double childAspectRatio = 0.75;

    return GridView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(outerPad, 12, outerPad, 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _GrowthThumbnailCard(
          record: record,
          isSelected: selectedIds.contains(record.id),
          onTap: () => isSelectionMode
              ? onToggleSelect(record.id)
              : onOpenFullImage(record),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
// 成長記録サムネイルカード
//
// model_list_screen.dart の _ModelThumbnailCard に準拠。
// ・画像エリア（Expanded・grey.shade100背景、Image.fileで実画像を表示）
// ・情報エリア（高さ68固定・白背景）
//   - 日付バッジ（テーマカラーの薄色ピル）
//   - 連番（アイコン＋太字）
//   - 所要時間（アイコン＋グレー文字、未入力時は非表示）
//
// ⚠ 長押し（範囲選択の開始）は親の _GrowthMainScreenState 側で
//   グリッド全体に対して一括処理している。このカード自体は
//   onTapのみを持つ（選択トグル or 拡大表示）。
// ══════════════════════════════════════════════════════════
class _GrowthThumbnailCard extends StatelessWidget {
  final GrowthRecord record;
  final bool isSelected;
  final VoidCallback onTap;

  const _GrowthThumbnailCard({
    required this.record,
    required this.isSelected,
    required this.onTap,
  });

  String get _dateBadgeLabel {
    final d = record.date;
    return '${d.month}/${d.day}';
  }

  String get _serialLabel =>
      '${record.serialNumber}${AppStrings.growthSerialSuffix}';

  String? get _durationLabel => record.durationMin != null
      ? '${record.durationMin}${AppStrings.growthDurationMinSuffix}'
      : null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? const BorderSide(color: AppColors.theme, width: 3)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 画像 ──
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.grey.shade100,
                    child: Image.file(
                      File(record.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                  // 選択中の半透明オーバーレイ＋チェックマーク
                  if (isSelected)
                    Container(
                      color: AppColors.theme.withOpacity(0.25),
                      child: const Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.theme,
                            child: Icon(Icons.check,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── 情報エリア ──（高さ固定でサムネイル領域を確保）
            SizedBox(
              height: 68,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 日付バッジ
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.themeLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _dateBadgeLabel,
                        style: TextStyle(
                            fontSize: 10, color: AppColors.themeDark),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 連番
                    Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined,
                            size: 13, color: AppColors.theme),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _serialLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    // 所要時間（未入力時は非表示）
                    if (_durationLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 11, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                _durationLabel!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
