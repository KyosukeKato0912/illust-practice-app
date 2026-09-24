import 'package:hive/hive.dart';
import '../../features/growth/domain/practice_day.dart';

// ══════════════════════════════════════════════════════════
// GrowthPracticeLogDataSource
//
// 継続カレンダー用の「練習日の記録」を Hive Box 'growth_practice_log'
// に保持する。GrowthRecord（growth_records）とは独立しているため、
// 画像を削除してもここの記録は消えない。
//
//   キー  : 'yyyy-MM-dd'
//   値    : {'count': アップロード枚数, 'minutes': 所要時間の合計(分)}
//           （Hive標準で扱えるMapのため TypeAdapter は不要）
//
// Hiveへの直接アクセスのみを担当する（移行判定などのロジックは
// GrowthRepository側が持つ）。
// ══════════════════════════════════════════════════════════
class GrowthPracticeLogDataSource {
  static const String boxName = 'growth_practice_log';
  static const String _keyCount = 'count';
  static const String _keyMinutes = 'minutes';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    return Hive.openBox(boxName);
  }

  String _keyFor(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 全件取得（順不同）
  Future<List<PracticeDay>> getAll() async {
    final box = await _openBox();
    final days = <PracticeDay>[];
    for (final key in box.keys) {
      if (key is! String) continue;
      final parts = key.split('-');
      if (parts.length != 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) continue;
      final value = box.get(key);
      if (value is! Map) continue;
      days.add(PracticeDay(
        date: DateTime(y, m, d),
        uploadCount: (value[_keyCount] as int?) ?? 0,
        totalMinutes: (value[_keyMinutes] as int?) ?? 0,
      ));
    }
    return days;
  }

  /// アップロード1件分を記録する（枚数+1・所要時間を加算）。
  Future<void> addUpload(DateTime date, int? durationMin) async {
    final box = await _openBox();
    final key = _keyFor(date);
    final current = box.get(key);
    final count = current is Map ? (current[_keyCount] as int? ?? 0) : 0;
    final minutes = current is Map ? (current[_keyMinutes] as int? ?? 0) : 0;
    await box.put(key, {
      _keyCount: count + 1,
      _keyMinutes: minutes + (durationMin ?? 0),
    });
  }

  /// その日の記録が無い場合のみ書き込む（既存データからの初回移行用）。
  Future<void> putIfAbsent(
    DateTime date, {
    required int uploadCount,
    required int totalMinutes,
  }) async {
    final box = await _openBox();
    final key = _keyFor(date);
    if (box.containsKey(key)) return;
    await box.put(key, {
      _keyCount: uploadCount,
      _keyMinutes: totalMinutes,
    });
  }
}
