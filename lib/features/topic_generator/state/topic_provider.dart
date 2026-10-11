import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/topic_repository.dart';

// ══════════════════════════════════════════════════════════
// TopicNotifier / topicProvider
//
// お題エリアに表示中のお題（String?・表示するお題が無いときは null）の状態管理。
// TopicMainScreen・TopicHistoryScreen の両方から参照されるため
// （画面をまたいで表示内容を保持する必要があるため）Riverpod
// StateNotifierとして実装する。GrowthNotifier と同様の設計方針。
//
// ・showLatestFromHistory() … お題ジェネレーター画面を開いたときに呼び、
//                       履歴の最新1件を表示する（履歴が空なら何も表示しない）。
// ・clearIfHistoryEmpty() … 履歴画面から戻ったときに呼び、履歴が空なら
//                       お題エリアの表示を消す。
// ・decide()         … 1〜3の選択（ランダムで回した結果を含む）で
//                       組み立てたお題を表示し、履歴にも追加する
//                       （メイン画面の決定ボタンからのみ呼び出す）。
// ・applyFromHistory() … お題履歴画面で選んだお題を表示する
//                       （履歴への追加は行わない＝重複追加の防止）。
// ・removeFromHistoryAt() … お題履歴から指定位置の1件を削除する。
//                       表示中のお題（お題エリア）には影響しない。
// ══════════════════════════════════════════════════════════
class TopicNotifier extends StateNotifier<String?> {
  final TopicRepository _repository;

  TopicNotifier({TopicRepository? repository})
      : _repository = repository ?? TopicRepository(),
        super(null);

  /// 履歴に保存されている最新のお題を表示する。履歴が空の場合は
  /// 何も表示しない（null）。お題ジェネレーター画面を開くたびに呼ぶ。
  Future<void> showLatestFromHistory() async {
    final history = await _repository.getHistory();
    state = history.isEmpty ? null : history.first;
  }

  /// 決定ボタンの確定処理。お題エリアへの表示と履歴への保存を行う。
  Future<void> decide(String topic) async {
    state = topic;
    await _repository.addToHistory(topic);
  }

  /// 履歴が空の場合のみ、お題エリアの表示を消す（null）。履歴画面で履歴を
  /// すべて削除して戻ってきたときに、前回のお題が残らないようにするために
  /// 呼ぶ。履歴が1件でも残っている場合は表示中のお題を変更しない。
  Future<void> clearIfHistoryEmpty() async {
    final history = await _repository.getHistory();
    if (history.isEmpty) state = null;
  }

  /// お題履歴画面での選択をお題エリアに反映する（履歴への追加はしない）。
  Future<void> applyFromHistory(String topic) async {
    state = topic;
  }

  /// お題履歴の [index] 番目（新しい順）を削除する。
  /// 履歴一覧（topicHistoryProvider）の再取得は呼び出し側で行うこと。
  Future<void> removeFromHistoryAt(int index) =>
      _repository.removeFromHistoryAt(index);
}

final topicProvider = StateNotifierProvider<TopicNotifier, String?>((ref) {
  return TopicNotifier();
});

// ══════════════════════════════════════════════════════════
// topicHistoryProvider
//
// お題履歴（新しい順・最大10件）。TopicHistoryScreen の表示専用で、
// 画面を開くたびに最新の履歴を取得したいため autoDispose な
// FutureProvider として実装する（決定後に再度開いたときも
// 追加直後の内容が反映される）。
// ══════════════════════════════════════════════════════════
final topicHistoryProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  return TopicRepository().getHistory();
});
