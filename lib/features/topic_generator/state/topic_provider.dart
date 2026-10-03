import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/topic_repository.dart';

// ══════════════════════════════════════════════════════════
// TopicNotifier / topicProvider
//
// お題エリアに表示中のお題（String?・未生成時は null）の状態管理。
// TopicMainScreen・TopicHistoryScreen の両方から参照されるため
// （画面をまたいで表示内容を保持する必要があるため）Riverpod
// StateNotifierとして実装する。GrowthNotifier と同様の設計方針。
//
// ・decide()         … 1〜3の選択（またはランダム）で組み立てたお題を
//                       表示し、履歴にも追加する（メイン画面の決定／
//                       ランダムボタンから呼び出す）。
// ・applyFromHistory() … お題履歴画面で選んだお題を表示する
//                       （履歴への追加は行わない＝重複追加の防止）。
// ══════════════════════════════════════════════════════════
class TopicNotifier extends StateNotifier<String?> {
  final TopicRepository _repository;

  TopicNotifier({TopicRepository? repository})
      : _repository = repository ?? TopicRepository(),
        super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await _repository.getCurrentTopic();
  }

  /// 決定／ランダム共通の確定処理。お題エリアへの表示と履歴への保存を行う。
  Future<void> decide(String topic) async {
    state = topic;
    await _repository.setCurrentTopic(topic);
    await _repository.addToHistory(topic);
  }

  /// お題履歴画面での選択をお題エリアに反映する（履歴への追加はしない）。
  Future<void> applyFromHistory(String topic) async {
    state = topic;
    await _repository.setCurrentTopic(topic);
  }
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
