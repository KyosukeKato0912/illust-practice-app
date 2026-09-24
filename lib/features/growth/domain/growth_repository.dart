import '../../../core/config/growth_config.dart';
import '../../../data/datasources/growth_datasource.dart';
import '../../../data/datasources/growth_meta_datasource.dart';
import '../../../data/datasources/growth_serial_counter_datasource.dart';
import 'growth_record.dart';

// ══════════════════════════════════════════════════════════
// GrowthRepository
//
// 成長記録のCRUDと、上限枚数（GrowthConfig.maxRecordCount）超過時の
// 自動削除ロジックを担当する。
// Hiveへのアクセスは GrowthDataSource / GrowthSerialCounterDataSource /
// GrowthMetaDataSource 経由のみ（直接Boxを操作しない）。
//
// ⚠ 画像ファイルの実体削除について
//   本クラスはHiveレコードの削除のみを行い、端末ローカルの画像ファイル
//   自体は削除しない（ファイルI/Oの責務は呼び出し側 = GrowthNotifier に
//   寄せる設計のため）。[add] は上限超過により自動削除された記録の
//   一覧を返すので、呼び出し側は必ずそれらの [GrowthRecord.imagePath]
//   のファイルも削除すること（放置するとファイルだけが端末に残り続ける）。
// ══════════════════════════════════════════════════════════
class GrowthRepository {
  final GrowthDataSource _dataSource;
  final GrowthSerialCounterDataSource _serialCounterDataSource;
  final GrowthMetaDataSource _metaDataSource;

  GrowthRepository({
    GrowthDataSource? dataSource,
    GrowthSerialCounterDataSource? serialCounterDataSource,
    GrowthMetaDataSource? metaDataSource,
  })  : _dataSource = dataSource ?? GrowthDataSource(),
        _serialCounterDataSource =
            serialCounterDataSource ?? GrowthSerialCounterDataSource(),
        _metaDataSource = metaDataSource ?? GrowthMetaDataSource();

  /// 全件取得（日付降順→連番降順の新しい順）
  Future<List<GrowthRecord>> getAll() async {
    final records = await _dataSource.getAll();
    records.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return b.serialNumber.compareTo(a.serialNumber);
    });
    return records;
  }

  /// 指定日の次の連番を発行する（ファイル名の「NN枚目」部分に使用）。
  ///
  /// GrowthRecordの現在の生存件数からではなく、
  /// [GrowthSerialCounterDataSource] の独立したカウンタから採番するため、
  /// 発行済みの連番は削除されても再利用されず、ファイル名は常に一意になる
  /// （例：10枚目を削除して再アップロードしても11枚目になる）。
  Future<int> nextSerialNumberForDate(DateTime date) async {
    final existing = await _serialCounterDataSource.peek(date);
    if (existing == null) {
      // このカウンタから一度も採番したことがない日＝
      // 本機能導入前からの既存データが残っている可能性があるため、
      // 既存レコードの最大連番からシードして整合性を保つ
      final all = await _dataSource.getAll();
      final sameDay = all.where((r) =>
          r.date.year == date.year &&
          r.date.month == date.month &&
          r.date.day == date.day);
      final seed = sameDay.isEmpty
          ? 0
          : sameDay.map((r) => r.serialNumber).reduce((a, b) => a > b ? a : b);
      await _serialCounterDataSource.seed(date, seed);
    }
    return _serialCounterDataSource.increment(date);
  }

  /// 1件追加し、上限枚数（[GrowthConfig.maxRecordCount]）を超えていれば
  /// 古いものから自動削除する。
  ///
  /// 戻り値は自動削除された記録の一覧（通常は空、または1件）。
  /// 画像ファイルの実体削除は行わないため、呼び出し側で削除すること。
  Future<List<GrowthRecord>> add(GrowthRecord record) async {
    await _dataSource.add(record);
    return _enforceMaxCount();
  }

  /// 1件削除
  Future<void> delete(String id) async {
    await _dataSource.delete(id);
  }

  /// 保持上限（[GrowthConfig.maxRecordCount]）に「初めて」到達したかどうか
  /// を判定する。
  ///
  /// 一度到達済み（フラグが立っている）の場合は、その後削除によって
  /// 件数が上限を下回り、再度上限に達しても false を返す
  /// （＝アップロード完了画面の特別メッセージは生涯で一度だけ）。
  Future<bool> checkFirstTimeReachedMax() async {
    final all = await _dataSource.getAll();
    if (all.length < GrowthConfig.maxRecordCount) return false;

    final alreadyReached = await _metaDataSource.hasReachedMaxCountOnce();
    if (alreadyReached) return false;

    await _metaDataSource.markReachedMaxCountOnce();
    return true;
  }

  /// 保持上限枚数に一度でも到達したことがあるか（現在のフラグ値）。
  /// [checkFirstTimeReachedMax] と異なり、判定のみで状態を変更しない。
  Future<bool> hasReachedMaxCountOnce() async {
    return _metaDataSource.hasReachedMaxCountOnce();
  }

  /// 【検証用】保持上限到達フラグをON/OFF切り替える。
  Future<void> setMaxCountReachedFlagForDebug(bool reached) async {
    if (reached) {
      await _metaDataSource.markReachedMaxCountOnce();
    } else {
      await _metaDataSource.resetHasReachedMaxCountOnce();
    }
  }

  Future<List<GrowthRecord>> _enforceMaxCount() async {
    final all = await _dataSource.getAll();
    if (all.length <= GrowthConfig.maxRecordCount) return const [];

    // 古い順（日付昇順→連番昇順）に並べ、超過分を削除する
    all.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return a.serialNumber.compareTo(b.serialNumber);
    });
    final overflowCount = all.length - GrowthConfig.maxRecordCount;
    final removed = <GrowthRecord>[];
    for (var i = 0; i < overflowCount; i++) {
      await _dataSource.delete(all[i].id);
      removed.add(all[i]);
    }
    return removed;
  }
}
