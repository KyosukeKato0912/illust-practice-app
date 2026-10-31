import 'package:flutter/services.dart';
import '../../../core/config/drawing_config.dart';

// ══════════════════════════════════════════════════════════
// X秒ドローイング モデルアセット
//
// ファイル名規則: draw-{categoryId}-{authorId}-{modelId}.{拡張子}
// 例: draw-c01-a01-m00001.png
//
// カテゴリ名・作者名・モデル名の文字列は DrawingConfig から取得する。
// ファイル名に日本語・特殊文字を含めないことでパースバグを防止。
// ══════════════════════════════════════════════════════════
class DrawingModel {
  final String path;

  /// ファイル名から抽出したカテゴリID（例: 'c01'）
  final String categoryId;

  /// ファイル名から抽出した作者ID（例: 'a01'）
  final String authorId;

  /// ファイル名から抽出したモデルID（例: 'm00001'）
  final String modelId;

  // ── DrawingConfig から解決した表示用データ ────────────
  /// カテゴリの定義。未定義IDの場合は null
  final DrawingCategoryDef? categoryDef;

  /// 作者の定義。未定義IDの場合は null
  final DrawingAuthorDef? authorDef;

  /// モデルの定義。未定義IDの場合は null
  final DrawingModelDef? modelDef;

  const DrawingModel({
    required this.path,
    required this.categoryId,
    required this.authorId,
    required this.modelId,
    required this.categoryDef,
    required this.authorDef,
    required this.modelDef,
  });

  // ── 表示用ゲッター ──────────────────────────────────────

  /// カテゴリ表示名（未定義IDの場合は ID をそのまま表示）
  String get categoryName => categoryDef?.name ?? categoryId;

  /// カテゴリ短縮表示名（未定義IDの場合は ID をそのまま表示）
  String get categoryShortName => categoryDef?.shortName ?? categoryId;

  /// 作者表示名（未定義IDの場合は ID をそのまま表示）
  String get authorName => authorDef?.displayName ?? authorId;

  /// モデル表示名（未定義IDの場合は ID をそのまま表示）
  String get modelName => modelDef?.name ?? modelId;

  /// サムネイルや一覧で表示するラベル
  String get label => modelName;

  // ── ファクトリ ──────────────────────────────────────────

  /// ファイルパスから [DrawingModel] を生成する。
  ///
  /// ファイル名規則: draw-{categoryId}-{authorId}-{modelId}.{拡張子}
  /// 規則に合わない場合は categoryId / authorId / modelId を空文字として扱い、
  /// 表示名はIDをそのままフォールバック表示する。
  factory DrawingModel.fromPath(String path) {
    final fileName = path.split('/').last;
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    // 'draw-c01-a01-m00001' → ['draw', 'c01', 'a01', 'm00001']
    final parts = nameWithoutExt.split('-');
    if (parts.length == 4 && parts[0] == 'draw') {
      final categoryId = parts[1];
      final authorId   = parts[2];
      final modelId    = parts[3];
      return DrawingModel(
        path:        path,
        categoryId:  categoryId,
        authorId:    authorId,
        modelId:     modelId,
        categoryDef: DrawingConfig.findCategory(categoryId),
        authorDef:   DrawingConfig.findAuthor(authorId),
        modelDef:    DrawingConfig.findModel(modelId),
      );
    }

    // 規則外ファイル：IDはすべて空扱いで、ファイル名をモデル名として表示
    return DrawingModel(
      path:        path,
      categoryId:  '',
      authorId:    '',
      modelId:     nameWithoutExt,
      categoryDef: null,
      authorDef:   null,
      modelDef:    null,
    );
  }
}

// ══════════════════════════════════════════════════════════
// モデルアセット一覧ローダー
//
// pubspec.yaml に assets/images/models/ フォルダを登録しておけば
// 追加した画像ファイルが自動的にリストに反映される。
//
// 使い方:
//   final models = await DrawingModelLoader.load();
// ══════════════════════════════════════════════════════════
class DrawingModelLoader {
  DrawingModelLoader._();

  // ロード結果をキャッシュし、複数画面からの二重呼び出しを防ぐ
  static Future<List<DrawingModel>>? _cache;

  /// assets/images/models/ 配下の画像を AssetManifest から動的に取得する。
  /// 2回目以降はキャッシュを返す。
  static Future<List<DrawingModel>> load() => _cache ??= _loadInternal();

  static Future<List<DrawingModel>> _loadInternal() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where((p) =>
            p.startsWith(DrawingConfig.modelAssetFolder) &&
            (p.endsWith('.png') ||
                p.endsWith('.jpg') ||
                p.endsWith('.jpeg') ||
                p.endsWith('.webp')))
        .toList();

    final models = paths.map(DrawingModel.fromPath).toList();

    // DrawingConfig.categories のリスト順 → モデル名 の順でソート
    models.sort((a, b) {
      final categoryCmp =
          DrawingConfig.categorySortIndex(a.categoryId)
              .compareTo(DrawingConfig.categorySortIndex(b.categoryId));
      if (categoryCmp != 0) return categoryCmp;
      return a.modelId.compareTo(b.modelId);
    });

    return models;
  }

  /// ロード済みリストから [DrawingCategoryDef] 一覧を取得する。
  ///
  /// DrawingConfig.categories の定義順を維持しつつ、
  /// 実際にアセットが存在するカテゴリだけを返す。
  static List<DrawingCategoryDef> categories(List<DrawingModel> models) {
    final presentIds = models.map((m) => m.categoryId).toSet();
    return DrawingConfig.categories
        .where((c) => presentIds.contains(c.id))
        .toList();
  }
}
