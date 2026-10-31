// ══════════════════════════════════════════════════════════
// X秒ドローイング コンフィグ
//
// ファイル名規則: draw-{categoryId}-{authorId}-{modelId}.{拡張子}
// 例: draw-c01-a01-mb00001.png
//
// ・カテゴリ・作者・モデルの表示名はここで一元管理する。
// ・ファイル名に特殊文字や日本語を含めないことでバグを防止。
// ・新しい画像を追加する際はこのファイルに定義を追加してから
//   assets/images/models/ に画像ファイルを配置すること。
//
// ■ 表示名の文字列について
//   カテゴリ名・作者名・モデル名はUIラベルではなくコンテンツのメタデータ
//   であるため、app_strings.dart には移さずここで管理する。
//   素材の追加・変更時に1ファイルだけ編集すれば済む構造を維持する。
//   ※ 将来の多言語化が必要になった場合は、各 Def クラスに nameJa / nameEn
//     等のフィールドを追加して対応する（app_strings.dart への移行は不要）。
//
// ■ ペアの扱いについて
//   同じモデル名を持つ異カテゴリのモデルが自動的にペアとして扱われる。
//   （例: mb00001「立ち」と md00001「立ち」は自動でペアになる）
//   ペアが存在しない場合は独立したモデルとして扱われる。
//   configにペア設定は不要。
// ══════════════════════════════════════════════════════════

// ── 終了メッセージ 重み定義 ───────────────────────────────

/// 終了メッセージの抽選重みを表す列挙型。
///
/// 実際の重みは [DrawingEndMessageDef.weightValue] で数値に変換される。
/// high:mid:low = 3:2:1 の比率で出現確率が変わる。
enum DrawingEndMessageWeight {
  high, // 高頻度（重み 3）
  mid, // 中頻度（重み 2）
  low, // 低頻度（重み 1）
}

/// 終了画面に表示するサブメッセージの定義。
///
/// 表示文言は [AppStrings.drawingEndMessages] の同インデックス要素を使用する。
/// テキストはここに持たず、app_strings.dart に一元管理する。
class DrawingEndMessageDef {
  /// [AppStrings.drawingEndMessages] 内のインデックス
  final int index;
  final DrawingEndMessageWeight weight;

  const DrawingEndMessageDef({
    required this.index,
    required this.weight,
  });

  /// 重み列挙型を数値に変換する。
  int get weightValue {
    switch (weight) {
      case DrawingEndMessageWeight.high:
        return 3;
      case DrawingEndMessageWeight.mid:
        return 2;
      case DrawingEndMessageWeight.low:
        return 1;
    }
  }
}

// ── カテゴリ定義 ──────────────────────────────────────────

/// X秒ドローイングで使用するモデルのカテゴリ定義。
///
/// [id]        ファイル名に使用するID（例: 'c01'）
/// [name]      画面に表示するカテゴリ名（例: 'ベーシック(6頭身)'）
/// [shortName] フィルタチップ等、スペースが限られた箇所での短縮表示名
class DrawingCategoryDef {
  final String id;
  final String name;
  final String shortName;

  const DrawingCategoryDef({
    required this.id,
    required this.name,
    required this.shortName,
  });
}

// ── 作者定義 ──────────────────────────────────────────────

/// X秒ドローイングで使用するモデルの作者定義。
///
/// [id]          ファイル名に使用するID（例: 'a01'）
/// [displayName] 画面に表示する作者名（例: 'Tyu☆'）
///               特殊文字・日本語を含んでよい（ファイル名には使わないため）
class DrawingAuthorDef {
  final String id;
  final String displayName;

  const DrawingAuthorDef({
    required this.id,
    required this.displayName,
  });
}

// ── モデル定義 ────────────────────────────────────────────

/// X秒ドローイングで使用する個々のモデル定義。
///
/// [id]   ファイル名に使用するID（例: 'mb00001'）
///        先頭2文字がカテゴリを示す（mb=ベーシック, md=デフォルメ, mf=顔, mh=手）
///        カテゴリ情報はファイル名の categoryId から取得するため、ここには持たない。
/// [name] 画面に表示するモデル名（例: '立ち'）
class DrawingModelDef {
  final String id;
  final String name;

  const DrawingModelDef({
    required this.id,
    required this.name,
  });
}

// ══════════════════════════════════════════════════════════
// 定義データ（新しい画像追加時はここに追記する）
// ══════════════════════════════════════════════════════════
abstract class DrawingConfig {
  /// ポーズモデル画像の格納フォルダ
  static const String modelAssetFolder = 'assets/images/models/';

  // ══════════════════════════════════════════════════════════
  // カテゴリ一覧 / 作者一覧 / モデル一覧
  // ══════════════════════════════════════════════════════════
  // リストの並び順 = 設定画面・モデル一覧でのカテゴリ表示順
  static const List<DrawingCategoryDef> categories = [
    DrawingCategoryDef(id: 'c01', name: 'ベーシック(6頭身)', shortName: 'ベーシック'),
    DrawingCategoryDef(id: 'c02', name: 'デフォルメ(2頭身)', shortName: 'デフォルメ'),
    DrawingCategoryDef(id: 'c03', name: '顔', shortName: '顔'),
    DrawingCategoryDef(id: 'c04', name: '手', shortName: '手'),
  ];

  // ── 作者一覧 ────────────────────────────────────────────
  static const List<DrawingAuthorDef> authors = [
    DrawingAuthorDef(id: 'a01', displayName: 'Tyu☆'),
  ];

  // ── モデル一覧 ──────────────────────────────────────────
  static const List<DrawingModelDef> models = [
    // ベーシック(6頭身)
    DrawingModelDef(id: 'mb00001', name: '立ち'),
    DrawingModelDef(id: 'mb00002', name: '座る'),
    DrawingModelDef(id: 'mb00003', name: '走る'),
    DrawingModelDef(id: 'mb00004', name: 'アイドル風'),
    DrawingModelDef(id: 'mb00005', name: '振り向く'),
    // デフォルメ(2頭身)
    DrawingModelDef(id: 'md00001', name: '立ち'),
    DrawingModelDef(id: 'md00002', name: '座る'),
    DrawingModelDef(id: 'md00003', name: '走る'),
    DrawingModelDef(id: 'md00004', name: 'アイドル風'),
    DrawingModelDef(id: 'md00005', name: '振り向く'),
    // 顔
    DrawingModelDef(id: 'mf00001', name: '女性通常'),
    DrawingModelDef(id: 'mf00002', name: '男性通常'),
    DrawingModelDef(id: 'mf00003', name: '笑顔'),
    DrawingModelDef(id: 'mf00004', name: '泣き顔'),
    DrawingModelDef(id: 'mf00005', name: '怒り'),
    // 手
    DrawingModelDef(id: 'mh00001', name: 'てのひら'),
    DrawingModelDef(id: 'mh00002', name: 'ピース'),
    DrawingModelDef(id: 'mh00003', name: '握りこぶし'),
    DrawingModelDef(id: 'mh00004', name: '指さす'),
    DrawingModelDef(id: 'mh00005', name: 'グッド'),
  ];

  // ══════════════════════════════════════════════════════════
  // 終了画面：ランダムメッセージ設定
  // ══════════════════════════════════════════════════════════

  /// 終了時に表示するサブメッセージの定義。
  ///
  /// [index] は [AppStrings.drawingEndMessages] のインデックスに対応する。
  /// 文言の追加・変更は app_strings.dart の [AppStrings.drawingEndMessages] で行い、
  /// こちらはインデックスと重みのみを管理する。
  ///
  /// [weight] 抽選の重み。high=3 / mid=2 / low=1 の比率で出現確率が変わる。
  static const List<DrawingEndMessageDef> endMessages = [
    DrawingEndMessageDef(
        index: 0, weight: DrawingEndMessageWeight.high), // 今日も一歩前進
    DrawingEndMessageDef(
        index: 1, weight: DrawingEndMessageWeight.mid), // お疲れ様でした
    DrawingEndMessageDef(
        index: 2, weight: DrawingEndMessageWeight.low), // よく頑張りました
    DrawingEndMessageDef(
        index: 3, weight: DrawingEndMessageWeight.low), // いいペースです
    DrawingEndMessageDef(
        index: 4, weight: DrawingEndMessageWeight.mid), // 明日も少しずつ
  ];

  // ══════════════════════════════════════════════════════════
  // ルックアップヘルパー
  // ══════════════════════════════════════════════════════════

  /// カテゴリIDから [DrawingCategoryDef] を返す。未定義IDの場合は null。
  static DrawingCategoryDef? findCategory(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 作者IDから [DrawingAuthorDef] を返す。未定義IDの場合は null。
  static DrawingAuthorDef? findAuthor(String id) {
    for (final a in authors) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// モデルIDから [DrawingModelDef] を返す。未定義IDの場合は null。
  static DrawingModelDef? findModel(String modelId) {
    for (final m in models) {
      if (m.id == modelId) return m;
    }
    return null;
  }

  /// カテゴリのソート順インデックスを返す。
  /// [categories] リストの並び順がそのまま表示順になる。
  static int categorySortIndex(String categoryId) {
    for (var i = 0; i < categories.length; i++) {
      if (categories[i].id == categoryId) return i;
    }
    return categories.length; // 未定義IDは末尾
  }
}
