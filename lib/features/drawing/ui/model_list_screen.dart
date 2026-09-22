import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/components/app_bar_widget.dart';
import '../../../core/config/drawing_config.dart';
import '../domain/drawing_model.dart';

// ══════════════════════════════════════════════════════════
// モデル一覧画面
//
// カテゴリ・モデル名でフィルタリングしたサムネグリッドを表示する。
// サムネをタップすると FullImageScreen に遷移する。
// ══════════════════════════════════════════════════════════
class ModelListScreen extends StatefulWidget {
  const ModelListScreen({super.key});

  @override
  State<ModelListScreen> createState() => _ModelListScreenState();
}

class _ModelListScreenState extends State<ModelListScreen> {
  late final Future<List<DrawingModel>> _modelsFuture;
  final TextEditingController _searchController = TextEditingController();

  List<DrawingModel> _all = [];
  List<DrawingCategoryDef> _categories = [];
  String? _selectedCategoryId; // null = すべて
  List<DrawingModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _modelsFuture = DrawingModelLoader.load();
    _modelsFuture.then((models) {
      if (mounted) _onAllLoaded(models);
    });
    _searchController.addListener(_applyFilter);
  }

  void _onAllLoaded(List<DrawingModel> models) {
    _all = models;
    _categories = DrawingModelLoader.categories(models);
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((model) {
        final categoryMatch =
            _selectedCategoryId == null || model.categoryId == _selectedCategoryId;
        final nameMatch =
            query.isEmpty || model.modelName.toLowerCase().contains(query);
        return categoryMatch && nameMatch;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() => _selectedCategoryId = null);
    _searchController.clear();
  }

  bool get _hasFilter =>
      _selectedCategoryId != null || _searchController.text.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: AppStrings.drawingModelListTitle,
        backgroundColor: AppColors.theme,
      ),
      body: FutureBuilder<List<DrawingModel>>(
        future: _modelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${AppStrings.modelListLoadError}\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, outerConstraints) {
              final double outerPad =
                  (outerConstraints.maxWidth * AppValues.outerPadRatio)
                      .clamp(AppValues.outerPadMin, AppValues.outerPadMax);

              return Column(
                children: [
                  // ── 検索エリア ──────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(outerPad, 12, outerPad, 4),
                    child: Column(
                      children: [
                        _CategoryDropdown(
                          categories: _categories,
                          selectedCategoryId: _selectedCategoryId,
                          onChanged: (value) {
                            setState(() => _selectedCategoryId = value);
                            _applyFilter();
                          },
                        ),
                        const SizedBox(height: 8),
                        _ModelNameSearchField(controller: _searchController),
                      ],
                    ),
                  ),

                  // ── 件数 ＋ フィルタークリア ────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: outerPad, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '${_filtered.length} 件',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const Spacer(),
                        if (_hasFilter)
                          TextButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.filter_alt_off, size: 14),
                            label: Text(
                              AppStrings.modelListFilterClear,
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.theme,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── サムネグリッド ──────────────────────────
                  Expanded(
                    child: _filtered.isEmpty
                        ? _ModelListEmptyState(hasFilter: _hasFilter)
                        : _ModelThumbnailGrid(
                            models: _filtered,
                            allModels: _all,
                            outerPad: outerPad,
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── カテゴリドロップダウン ──────────────────────────────────
class _CategoryDropdown extends StatelessWidget {
  final List<DrawingCategoryDef> categories;
  final String? selectedCategoryId; // カテゴリID or null（すべて）
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      value: selectedCategoryId,
      decoration: InputDecoration(
        labelText: AppStrings.modelListCategoryLabel,
        prefixIcon: const Icon(Icons.folder_outlined, color: AppColors.theme),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.theme, width: 2),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(AppStrings.modelListCategoryAll),
        ),
        ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
      ],
      onChanged: onChanged,
    );
  }
}

// ── モデル名検索フィールド ──────────────────────────────────
class _ModelNameSearchField extends StatelessWidget {
  final TextEditingController controller;

  const _ModelNameSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: AppStrings.modelListModelNameLabel,
        hintText: AppStrings.modelListModelNameHint,
        prefixIcon: const Icon(Icons.search, color: AppColors.theme),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: controller.clear,
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.theme, width: 2),
        ),
        isDense: true,
      ),
    );
  }
}

// ── サムネグリッド ──────────────────────────────────────────
class _ModelThumbnailGrid extends StatelessWidget {
  final List<DrawingModel> models;
  final List<DrawingModel> allModels;
  final double outerPad;

  const _ModelThumbnailGrid({
    required this.models,
    required this.allModels,
    required this.outerPad,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // スマホ（幅600未満）は2列固定、タブレット以上は幅に応じて増やす
        final int crossAxisCount = constraints.maxWidth < 600
            ? 2
            : (constraints.maxWidth / 280.0).floor().clamp(2, 8);

        // 情報エリア（カテゴリ・モデル名・作者名）の高さを考慮してアスペクト比を調整
        // 画像部分が十分に見えるよう縦長に設定
        const double childAspectRatio = 0.75;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            outerPad,
            AppValues.gridContentPadding,
            outerPad,
            AppValues.gridContentPadding +
                MediaQuery.paddingOf(context).bottom,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: models.length,
          itemBuilder: (context, index) {
            final model = models[index];
            return _ModelThumbnailCard(
              model: model,
              onTap: () => Navigator.push(
                context,
                AppRouter.drawingFullImage(
                  initialAsset: model,
                  allAssets: allModels,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── データなし空状態 ────────────────────────────────────────
class _ModelListEmptyState extends StatelessWidget {
  final bool hasFilter;

  const _ModelListEmptyState({required this.hasFilter});

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
                ? AppStrings.modelListEmptyFiltered
                : AppStrings.modelListEmptyNoImages,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// モデルサムネイルカード
// ══════════════════════════════════════════════════════════
class _ModelThumbnailCard extends StatelessWidget {
  final DrawingModel model;
  final VoidCallback onTap;

  const _ModelThumbnailCard({required this.model, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 画像 ──
            Expanded(
              child: Container(
                color: Colors.grey.shade100,
                child: Image.asset(
                  model.path,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ),
            // ── 情報エリア ──（高さ固定でサムネイル領域を確保）
            SizedBox(
              height: 68,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // カテゴリバッジ
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: double.infinity),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.themeLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          model.categoryName,
                          style: TextStyle(
                              fontSize: 10, color: AppColors.themeDark),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // モデル名
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: AppColors.theme),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            model.modelName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const Icon(Icons.open_in_full,
                            size: 11, color: Colors.grey),
                      ],
                    ),
                    // 作者名
                    if (model.authorName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Row(
                          children: [
                            Icon(Icons.brush_outlined,
                                size: 11, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                '${AppStrings.drawingAuthorPrefix}${model.authorName}',
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
