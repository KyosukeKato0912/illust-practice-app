import 'package:hive/hive.dart';

// ══════════════════════════════════════════════════════════
// TopicHistoryDataSource
//
// お題ジェネレーターの永続データを保持する。
//   ・現在お題エリアに表示中のお題（アプリ再起動後も表示を保つ）
//   ・お題履歴（直近10件、新しい順）
// GrowthMetaDataSource と同様、専用Hiveアダプタは使わず
// プリミティブ型（String / List<String>）のまま保存する。
// ══════════════════════════════════════════════════════════
class TopicHistoryDataSource {
  static const String boxName = 'topic_history';
  static const String _keyCurrentTopic = 'current_topic';
  static const String _keyHistory = 'history';

  /// お題履歴として保持する最大件数（UI設計_お題ジェネレーター シート準拠）
  static const int maxHistoryCount = 10;

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    return Hive.openBox(boxName);
  }

  /// 現在お題エリアに表示中のお題。未生成の場合は null。
  Future<String?> getCurrentTopic() async {
    final box = await _openBox();
    return box.get(_keyCurrentTopic) as String?;
  }

  /// 現在お題エリアに表示中のお題を保存する。
  Future<void> setCurrentTopic(String topic) async {
    final box = await _openBox();
    await box.put(_keyCurrentTopic, topic);
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
}
