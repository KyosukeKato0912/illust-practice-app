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
// ⚠ 現フェーズ：保存先パスの組み立てのみを提供する。
//   実際の画像保存（File書き込み）・削除処理は、
//   image_picker 導入後に GrowthRepository / GrowthDataSource から
//   このヘルパーを介して呼び出す想定。
// ══════════════════════════════════════════════════════════
abstract class AppFileUtils {
  /// 成長記録画像を格納するディレクトリ名
  /// （アプリ専用ローカルストレージ配下に作成する）
  static const String growthImagesDirName = 'growth_images';

  /// 成長記録画像の保存先ディレクトリを取得する。
  /// 未作成の場合はディレクトリを作成してから返す。
  static Future<Directory> growthImagesDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocDir.path}/$growthImagesDirName');
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
