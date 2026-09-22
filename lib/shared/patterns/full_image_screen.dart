import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_values.dart';
import '../../core/config/drawing_config.dart';
import '../../features/drawing/domain/drawing_model.dart';
import '../components/app_bar_widget.dart';

// ══════════════════════════════════════════════════════════
// 拡大表示画面（shared パターン）
//
// X秒ドローイング モデル一覧から遷移する拡大表示画面。
// 現フェーズは DrawingModel のみ対応。
//
// ⚠ 依存注意：shared → features/drawing への参照が発生している。
//   他機能が利用する際は DrawingModel を抽象インターフェース
//   （例: DisplayableAsset）に置き換え、依存を逆転させること。
//   変更対象: initialAsset・allAssets の型 + ペア検索ロジック。
//
// 機能：
//   - ピンチ操作による拡大・縮小（InteractiveViewer）
//   - ペアモデル（同名・異カテゴリ）がある場合は頭身切り替えボタンを表示
// ══════════════════════════════════════════════════════════
class FullImageScreen extends StatefulWidget {
  /// 最初に表示するモデルアセット
  final DrawingModel initialAsset;

  /// ペア検索に使用する全アセット一覧
  final List<DrawingModel> allAssets;

  /// AppBar・アクセントカラー（呼び出し機能のカラーに合わせる）
  final Color appBarColor;

  const FullImageScreen({
    super.key,
    required this.initialAsset,
    required this.allAssets,
    this.appBarColor = AppColors.theme,
  });

  @override
  State<FullImageScreen> createState() => _FullImageScreenState();
}

class _FullImageScreenState extends State<FullImageScreen> {
  late DrawingModel _current;

  /// 同名モデルをカテゴリ順に並べたペアリスト（自身を含む）
  late List<DrawingModel> _pairs;

  /// _pairs 内の現在表示インデックス。
  late int _currentPairIndex;

  /// ペアが2件以上ある（= 切り替え可能）か
  bool get _hasPair => _pairs.length >= 2;

  /// 現在のカテゴリと同じモデルのリスト（前へ/次へボタン用）
  late List<DrawingModel> _sameCategoryAssets;

  /// _sameCategoryAssets 内での現在インデックス
  late int _categoryIndex;

  // allAssets に存在するカテゴリIDを DrawingConfig の定義順で返す
  List<String> get _presentCategoryIds {
    final ids = widget.allAssets.map((a) => a.categoryId).toSet();
    return DrawingConfig.categories
        .where((c) => ids.contains(c.id))
        .map((c) => c.id)
        .toList();
  }

  // 非活性条件：全カテゴリ中の先頭かつカテゴリ内先頭
  bool get _isFirst =>
      _presentCategoryIds.first == _current.categoryId &&
      _categoryIndex <= 0;

  // 非活性条件：全カテゴリ中の末尾かつカテゴリ内末尾
  bool get _isLast =>
      _presentCategoryIds.last == _current.categoryId &&
      _categoryIndex >= _sameCategoryAssets.length - 1;

  // ペア内のカテゴリ表示優先順は DrawingConfig.categorySortIndex に従う

  @override
  void initState() {
    super.initState();
    _current = widget.initialAsset;

    _pairs = widget.allAssets
        .where((a) => a.modelName == widget.initialAsset.modelName)
        .toList()
      ..sort((a, b) => DrawingConfig.categorySortIndex(a.categoryId)
          .compareTo(DrawingConfig.categorySortIndex(b.categoryId)));

    // ペアリスト内でのインデックス
    final idx = _pairs.indexWhere((a) => a.path == widget.initialAsset.path);
    _currentPairIndex = idx != -1 ? idx : 0;

    // 同カテゴリのアセットリストと現在インデックス
    _sameCategoryAssets = _buildSameCategoryList(widget.initialAsset);
    final cIdx = _sameCategoryAssets.indexWhere((a) => a.path == widget.initialAsset.path);
    _categoryIndex = cIdx != -1 ? cIdx : 0;
  }

  /// ペアリスト内で次のモデルに切り替える（頭身切り替えボタン）
  void _togglePair() {
    if (!_hasPair) return;
    _currentPairIndex = (_currentPairIndex + 1) % _pairs.length;
    setState(() {
      _current = _pairs[_currentPairIndex];
      // カテゴリが変わったので前後移動コンテキストを更新
      _refreshCategoryContext();
    });
  }

  /// 前の画像に移動（カテゴリ先頭の場合は前カテゴリの末尾へ）
  void _prevAsset() {
    if (_isFirst) return;
    if (_categoryIndex > 0) {
      // カテゴリ内を前へ
      _categoryIndex--;
      _switchToCategory();
    } else {
      // カテゴリをまたいで前カテゴリの末尾へ
      final ids = _presentCategoryIds;
      final pos = ids.indexOf(_current.categoryId);
      final prevCategoryId = ids[pos - 1];
      final prevList = _buildSameCategoryListById(prevCategoryId);
      _moveToCategoryList(prevList, prevList.length - 1);
    }
  }

  /// 次の画像に移動（カテゴリ末尾の場合は次カテゴリの先頭へ）
  void _nextAsset() {
    if (_isLast) return;
    if (_categoryIndex < _sameCategoryAssets.length - 1) {
      // カテゴリ内を次へ
      _categoryIndex++;
      _switchToCategory();
    } else {
      // カテゴリをまたいで次カテゴリの先頭へ
      final ids = _presentCategoryIds;
      final pos = ids.indexOf(_current.categoryId);
      final nextCategoryId = ids[pos + 1];
      final nextList = _buildSameCategoryListById(nextCategoryId);
      _moveToCategoryList(nextList, 0);
    }
  }

  /// _categoryIndex の画像に切り替え、ペアリストを再構築する
  void _switchToCategory() {
    final next = _sameCategoryAssets[_categoryIndex];
    final newPairs = widget.allAssets
        .where((a) => a.modelName == next.modelName)
        .toList()
      ..sort((a, b) => DrawingConfig.categorySortIndex(a.categoryId)
          .compareTo(DrawingConfig.categorySortIndex(b.categoryId)));
    final pIdx = newPairs.indexWhere((a) => a.path == next.path);
    setState(() {
      _current = next;
      _pairs
        ..clear()
        ..addAll(newPairs);
      _currentPairIndex = pIdx != -1 ? pIdx : 0;
    });
  }

  /// 頭身切り替え後：同カテゴリリストと現在インデックスを更新する
  void _refreshCategoryContext() {
    _sameCategoryAssets = _buildSameCategoryList(_current);
    final cIdx = _sameCategoryAssets.indexWhere((a) => a.path == _current.path);
    _categoryIndex = cIdx != -1 ? cIdx : 0;
  }

  /// 指定モデルと同じ categoryId のアセットをモデルID順で返す
  List<DrawingModel> _buildSameCategoryList(DrawingModel model) =>
      _buildSameCategoryListById(model.categoryId);

  /// 指定 categoryId のアセットをモデルID順で返す
  List<DrawingModel> _buildSameCategoryListById(String categoryId) {
    return widget.allAssets
        .where((a) => a.categoryId == categoryId)
        .toList()
      ..sort((a, b) => a.modelId.compareTo(b.modelId));
  }

  /// 指定リスト・指定インデックスの画像に移動しコンテキストを更新する
  void _moveToCategoryList(List<DrawingModel> list, int index) {
    final next = list[index];
    final newPairs = widget.allAssets
        .where((a) => a.modelName == next.modelName)
        .toList()
      ..sort((a, b) => DrawingConfig.categorySortIndex(a.categoryId)
          .compareTo(DrawingConfig.categorySortIndex(b.categoryId)));
    final pIdx = newPairs.indexWhere((a) => a.path == next.path);
    setState(() {
      _current = next;
      _sameCategoryAssets = list;
      _categoryIndex = index;
      _pairs
        ..clear()
        ..addAll(newPairs);
      _currentPairIndex = pIdx != -1 ? pIdx : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.enlargeViewTitle,
        backgroundColor: widget.appBarColor,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double outerPad =
              (constraints.maxWidth * AppValues.outerPadRatio)
                  .clamp(AppValues.outerPadMin, AppValues.outerPadMax);

          return Column(
            children: [
              // ── 情報バー（カテゴリ・モデル名・作者） ──────────────
              _InfoBar(
                model: _current,
                accentColor: widget.appBarColor,
                outerPad: outerPad,
              ),

              // ── 画像表示エリア ──────────────────────────────────
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: outerPad),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Image.asset(_current.path, fit: BoxFit.contain),
                  ),
                ),
              ),

              // ── ボタンエリア（前へ ／ 頭身切り替え ／ 次へ）3分割 ──
              Padding(
                padding: EdgeInsets.fromLTRB(outerPad, 8, outerPad, 4),
                child: Row(
                  children: [
                    // 前の画像へ（常に同じ幅・位置）
                    Expanded(
                      child: _NavButton(
                        icon: Icons.chevron_left,
                        color: widget.appBarColor,
                        enabled: !_isFirst,
                        onPressed: _prevAsset,
                      ),
                    ),
                    // 頭身切り替え：ペアあり→実ボタン、なし→透明ダミーで幅を確保
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: _hasPair
                          ? ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.appBarColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _togglePair,
                              icon: const Icon(Icons.swap_vert, size: 18),
                              label: Text(
                                '${AppStrings.drawingToggleHeightButton}（${_current.categoryShortName}）',
                                style: const TextStyle(fontSize: 13),
                              ),
                            )
                          : const SizedBox(height: 44), // 幅確保用ダミー
                    ),
                    // 次の画像へ（常に同じ幅・位置）
                    const SizedBox(width: 6),
                    Expanded(
                      child: _NavButton(
                        icon: Icons.chevron_right,
                        color: widget.appBarColor,
                        enabled: !_isLast,
                        onPressed: _nextAsset,
                      ),
                    ),
                  ],
                ),
              ),

              // ── ピンチヒント ────────────────────────────────────
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
  final DrawingModel model;
  final Color accentColor;
  final double outerPad;

  const _InfoBar({
    required this.model,
    required this.accentColor,
    required this.outerPad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: accentColor.withAlpha(20),
      padding: EdgeInsets.fromLTRB(outerPad, 8, outerPad, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 2,
        children: [
          if (model.categoryName.isNotEmpty)
            _InfoChip(
              icon: Icons.folder_outlined,
              label: model.categoryName,
              color: accentColor,
            ),
          _InfoChip(
            icon: Icons.image_outlined,
            label: model.modelName,
            color: accentColor,
          ),
          if (model.authorName.isNotEmpty)
            _InfoChip(
              icon: Icons.brush_outlined,
              label: '${AppStrings.drawingAuthorPrefix}${model.authorName}',
              color: accentColor,
            ),
        ],
      ),
    );
  }
}

// ── 前へ/次へナビゲーションボタン ─────────────────────────
// アイコンのみ・四角ボタン。非活性時はグレーで表示。
class _NavButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  const _NavButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : Colors.grey.shade300,
        foregroundColor: enabled ? Colors.white : Colors.grey.shade500,
        minimumSize: const Size(0, 44),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: enabled ? onPressed : null,
      child: Icon(icon, size: 28),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withAlpha(180)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

