import '../../../data/datasources/topic_history_datasource.dart';

// ══════════════════════════════════════════════════════════
// TopicRepository
//
// ui/ ・ state/ からは本クラス経由でのみ永続データにアクセスする
// （他機能と同様、TopicHistoryDataSource・Hiveを直接操作しない）。
// ══════════════════════════════════════════════════════════
class TopicRepository {
  final TopicHistoryDataSource _dataSource;

  TopicRepository({TopicHistoryDataSource? dataSource})
      : _dataSource = dataSource ?? TopicHistoryDataSource();

  Future<List<String>> getHistory() => _dataSource.getHistory();

  Future<void> addToHistory(String topic) =>
      _dataSource.addToHistory(topic);

  Future<void> removeFromHistoryAt(int index) =>
      _dataSource.removeFromHistoryAt(index);
}
