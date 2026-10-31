// ══════════════════════════════════════════════════════════
// 習慣化サポート コンフィグ
//
// ファイル名規則: {連番3桁}.webp
// 例: 001.webp
//
// ・継続カレンダーの花丸画像など、複数パターンから選択しうる
//   コンテンツ素材の定義をここで一元管理する。
// ・新しい画像を追加する際はこのファイルに定義を追加してから
//   assets/images/ui/habit/ に画像ファイルを配置すること。
//
// ■ DrawingConfig との対応関係
//   X秒ドローイングの drawing_config.dart と同じ設計思想に基づく。
//   コンテンツのメタデータ（ID・表示名・選択ロジック）はこちらで管理し、
//   固定値・UI寸法等は app_values.dart に置く。
// ══════════════════════════════════════════════════════════

// ── 花丸画像定義 ──────────────────────────────────────────

/// 継続カレンダーの記録セルに表示する花丸画像の定義。
///
/// [id]    ファイル名に使用するID（例: '001'）
/// [name]  選択画面等で表示する名称（例: 'スタンダード'）
class HabitFlowerCircleDef {
  final String id;
  final String name;

  const HabitFlowerCircleDef({
    required this.id,
    required this.name,
  });
}

// ══════════════════════════════════════════════════════════
// 定義データ（新しい画像追加時はここに追記する）
// ══════════════════════════════════════════════════════════
abstract class HabitConfig {
  // ── アセット格納フォルダ ──────────────────────────────────
  static const String flowerCircleAssetFolder = 'assets/images/ui/habit/';

  // ── 花丸画像一覧 ──────────────────────────────────────────
  // リストの並び順 = 将来の選択画面での表示順
  static const List<HabitFlowerCircleDef> flowerCircles = [
    HabitFlowerCircleDef(id: '001', name: 'スタンダード'),
  ];

  // ── 現在使用する花丸画像のID ──────────────────────────────
  // 将来、ユーザーが選択できるようになった際は
  // ユーザー設定値（DrawingSettings 同様の仕組み）から取得する形に差し替える。
  static const String defaultFlowerCircleId = '001';

  // ══════════════════════════════════════════════════════════
  // ルックアップヘルパー
  // ══════════════════════════════════════════════════════════

  /// 花丸画像IDから [HabitFlowerCircleDef] を返す。未定義IDの場合は null。
  static HabitFlowerCircleDef? findFlowerCircle(String id) {
    for (final f in flowerCircles) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// 花丸画像IDからアセットパスを返す。
  static String flowerCircleAssetPath(String id) =>
      '$flowerCircleAssetFolder$id.webp';

  /// 現在使用する花丸画像のアセットパスを返す。
  static String get currentFlowerCircleAssetPath =>
      flowerCircleAssetPath(defaultFlowerCircleId);
}
