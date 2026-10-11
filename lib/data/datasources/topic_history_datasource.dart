import 'package:hive/hive.dart';

// ══════════════════════════════════════════════════════════
// TopicHistoryDataSource
//
// お題ジェネレーターの永続データを保持する。
//   ・お題履歴（直近10件、新しい順）
// （お題エリアの表示は、画面を開くたびに履歴の最新1件から決まるため、
// 「現在表示中のお題」自体は保存しない）
// GrowthMetaDataSource と同様、専用Hiveアダプタは使わず
// プリミティブ型（String / List<String>）のまま保存する。
// ══════════════════════════════════════════════════════════
class TopicHistoryDataSource {
  static const String boxName = 'topic_history';
  static const String _keyHistory = 'history';

  /// お題履歴として保持する最大件数（UI設計_お題ジェネレーター シート準拠）
  static const int maxHistoryCount = 10;

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    return Hive.openBox(boxName);
  }

  /// お題履歴（新しい順）。
  Future<List<String>> getHistory() async {
    final box = await _openBox();
    final raw = box.get(_keyHistory);
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  /// お題履歴の先頭に追加し、[maxHistoryCount] 件を超えた分は古いものから削除する。
  Future<void> addToHistory(String topic) async {
    final box = await _openBox();
    final current = await getHistory();
    final updated = [topic, ...current].take(maxHistoryCount).toList();
    await box.put(_keyHistory, updated);
  }

  /// お題履歴の [index] 番目（新しい順の並びでの位置）を削除する。
  /// 範囲外の場合は何もしない。同じお題が複数回履歴に入ることがあるため、
  /// 値ではなく位置で削除する。
  Future<void> removeFromHistoryAt(int index) async {
    final box = await _openBox();
    final current = await getHistory();
    if (index < 0 || index >= current.length) return;
    final updated = [...current]..removeAt(index);
    await box.put(_keyHistory, updated);
  }
}
