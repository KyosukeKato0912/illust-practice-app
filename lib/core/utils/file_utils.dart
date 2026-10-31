import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../constants/app_strings.dart';

// ══════════════════════════════════════════════════════════
// 画像保存パス・一時ファイル操作ヘルパー
//
// 成長記録機能でユーザーがアップロードした画像は、
// assets/（ビルド時同梱・読み取り専用）ではなく、
// path_provider で取得する端末ローカルのアプリ専用ディレクトリに
// 保存する。保存先ディレクトリ・ファイル名の組み立てをここに集約し、
// 複数箇所での重複実装を防ぐ。
//
// このヘルパーは保存先ディレクトリ・ファイル名・フルパスの組み立てのみを
// 提供する。実際の画像のコピー保存・削除は GrowthNotifier
// （features/growth/state/growth_provider.dart）が行い、
// 保存先パスの決定にこのヘルパーを利用している。
// ══════════════════════════════════════════════════════════
abstract class AppFileUtils {
  /// 成長記録画像を格納するディレクトリ名
  /// （アプリ専用ローカルストレージ配下に作成する）
  static const String growthImagesDirName = 'growth_images';

  /// アプリ専用ドキュメントディレクトリのパス（[initialize] で設定）。
  /// Hive の TypeAdapter.read は同期処理のため、非同期の
  /// getApplicationDocumentsDirectory() を呼べない。そのため起動時に1度だけ
  /// 取得してここに保持し、保存パスの相対⇔絶対の変換に使う。
  static String? _documentsDirPath;

  /// 起動時（Hiveを使う前）に1度だけ呼ぶ。
  /// 取得できない環境（Web等）では例外を投げるので、呼び出し側で握りつぶすこと。
  /// その場合 [resolveStoredPath] は保存値をそのまま返す。
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _documentsDirPath = dir.path;
  }

  // ── 保存パスの相対化 ──────────────────────────────────
  // Hive には端末ごとの絶対パスではなく
  //   growth_images/<ファイル名>
  // という相対パスを保存し、読み出し時に現在のドキュメントディレクトリを
  // 前置して絶対パスに戻す。アプリのデータ領域のパスが変わっても
  // （端末移行・OS更新・復元など）画像を参照できるようにするための仕組み。
  //
  // ⚠ 旧バージョンで絶対パス保存したデータも、パス内の
  //   '/growth_images/' 以降を取り出して現在のディレクトリに付け替えるため、
  //   移行処理なしでそのまま読める。

  static const String _storedMarker = '/$growthImagesDirName/';

  /// 絶対パスを Hive 保存用の相対パス（growth_images/<名前>）に変換する。
  /// 成長記録の保存先ディレクトリ配下でないパスは、そのまま返す。
  static String toStoredPath(String absolutePath) {
    final index = absolutePath.indexOf(_storedMarker);
    if (index == -1) return absolutePath;
    return absolutePath.substring(index + 1);
  }

  /// Hive の保存値（相対パス、または旧形式の絶対パス）を、
  /// 現在の端末で使える絶対パスに変換する。
  static String resolveStoredPath(String storedPath) {
    final base = _documentsDirPath;
    if (base == null) return storedPath; // 未初期化（Web等）：そのまま使う

    if (storedPath.startsWith('$growthImagesDirName/')) {
      return '$base/$storedPath'; // 相対パス（新形式）
    }
    final index = storedPath.indexOf(_storedMarker);
    if (index != -1) {
      return '$base${storedPath.substring(index)}'; // 旧形式の絶対パスを付け替え
    }
    return storedPath;
  }

  /// 成長記録画像の保存先ディレクトリを取得する。
  /// 未作成の場合はディレクトリを作成してから返す。
  static Future<Directory> growthImagesDirectory() async {
    final basePath = _documentsDirPath ??
        (await getApplicationDocumentsDirectory()).path;
    final dir = Directory('$basePath/$growthImagesDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 成長記録画像のファイル名を組み立てる。
  ///
  /// 日付・連番（・所要時間）からファイル名を一意に決定する。
  /// 所要時間が指定されている場合は末尾に付与する。
  /// 例：
  ///   durationMin指定なし → date=2026-06-01, serialNumber=2
  ///     → '2026-06-01-2枚目.png'
  ///   durationMin=3       → date=2026-06-01, serialNumber=2
  ///     → '2026-06-01-2枚目-3分.png'
  static String buildGrowthImageFileName({
    required DateTime date,
    required int serialNumber,
    int? durationMin,
    String extension = 'png',
  }) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final base =
        '$y-$m-$d-$serialNumber${AppStrings.growthFileNameSerialSuffix}';
    final name = durationMin != null
        ? '$base-$durationMin${AppStrings.growthFileNameMinuteSuffix}'
        : base;
    return '$name.$extension';
  }

  /// 成長記録画像の保存先フルパスを取得する。
  ///
  /// ディレクトリが未作成の場合は作成される。
  static Future<String> growthImageFilePath({
    required DateTime date,
    required int serialNumber,
    int? durationMin,
    String extension = 'png',
  }) async {
    final dir = await growthImagesDirectory();
    final fileName = buildGrowthImageFileName(
      date: date,
      serialNumber: serialNumber,
      durationMin: durationMin,
      extension: extension,
    );
    return '${dir.path}/$fileName';
  }
}
