import 'package:hive/hive.dart';
import '../../../core/utils/file_utils.dart';

// ══════════════════════════════════════════════════════════
// 成長記録 値オブジェクト（Hiveモデル）
//
// typeId は core/constants/app_values.dart で一元管理する
// （重複登録防止のため、新規Hiveモデル追加時は必ずそちらも確認する）。
//
// ⚠ build_runner（hive_generator）は使わず、TypeAdapter
//   （GrowthRecordAdapter）を手書きしている。コード生成環境に
//   依存せずビルドできるようにするための方針。
// ══════════════════════════════════════════════════════════
class GrowthRecord {
  final String id;

  /// 画像ファイルの絶対パス（path_provider 経由のローカルファイル）。
  /// ⚠ メモリ上では絶対パスだが、Hive には相対パス（growth_images/<名前>）で
  ///   保存する。変換は GrowthRecordAdapter が行う（AppFileUtils 参照）。
  final String imagePath;

  /// アップロード日（時刻は無視し日付のみを保持する）
  final DateTime date;

  /// 同一日内でのアップロード連番（1始まり）
  final int serialNumber;

  /// 所要時間（分）。任意入力のため未入力時は null
  final int? durationMin;

  GrowthRecord({
    required this.id,
    required this.imagePath,
    required this.date,
    required this.serialNumber,
    this.durationMin,
  });
}

// ── Hive TypeAdapter（手書き） ────────────────────────────
class GrowthRecordAdapter extends TypeAdapter<GrowthRecord> {
  @override
  final int typeId = 0;

  @override
  GrowthRecord read(BinaryReader reader) {
    final id = reader.readString();
    // 保存値（相対パス／旧形式の絶対パス）を現在の端末の絶対パスに変換する
    final imagePath = AppFileUtils.resolveStoredPath(reader.readString());
    final dateMillis = reader.readInt();
    final serialNumber = reader.readInt();
    final hasDuration = reader.readBool();
    final durationMin = hasDuration ? reader.readInt() : null;
    return GrowthRecord(
      id: id,
      imagePath: imagePath,
      date: DateTime.fromMillisecondsSinceEpoch(dateMillis),
      serialNumber: serialNumber,
      durationMin: durationMin,
    );
  }

  @override
  void write(BinaryWriter writer, GrowthRecord obj) {
    writer.writeString(obj.id);
    writer.writeString(AppFileUtils.toStoredPath(obj.imagePath));
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeInt(obj.serialNumber);
    writer.writeBool(obj.durationMin != null);
    if (obj.durationMin != null) {
      writer.writeInt(obj.durationMin!);
    }
  }
}
