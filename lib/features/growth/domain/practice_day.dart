import 'growth_record.dart';

// ══════════════════════════════════════════════════════════
// PracticeDay（練習日の記録）
//
// 継続カレンダー（習慣化サポート／成長記録のアップロード完了画面）が
// 参照する「1日分の練習記録」。
//
// GrowthRecord（画像そのもの）とは独立して永続化されるため、
// 画像を削除しても（上限超過による自動削除を含む）記録は残り続ける。
//   ・date        : アップロードした日（時刻は切り捨てた日付のみ）
//   ・uploadCount : その日のアップロード枚数（削除しても減らない）
//   ・totalMinutes: その日に入力された所要時間（分）の合計
//                   （未入力のアップロードは0分として扱う）
// ══════════════════════════════════════════════════════════
class PracticeDay {
  final DateTime date;
  final int uploadCount;
  final int totalMinutes;

  const PracticeDay({
    required this.date,
    required this.uploadCount,
    required this.totalMinutes,
  });

  /// GrowthRecord の一覧から日付ごとの記録を集計する
  /// （テストデータの変換・既存データの初回移行用）。
  static List<PracticeDay> fromRecords(List<GrowthRecord> records) {
    final byDate = <DateTime, List<int>>{}; // [枚数, 合計分]
    for (final r in records) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      final acc = byDate.putIfAbsent(d, () => [0, 0]);
      acc[0] += 1;
      acc[1] += r.durationMin ?? 0;
    }
    return [
      for (final e in byDate.entries)
        PracticeDay(
          date: e.key,
          uploadCount: e.value[0],
          totalMinutes: e.value[1],
        ),
    ];
  }

  /// [a]・[b] を日付ごとに合算する（メンテナンス画面の「併用」モード用：
  /// テストデータと実データを同じ継続記録として扱いたい場合に使う）。
  /// 同じ日に両方の記録がある場合は uploadCount・totalMinutes を加算する。
  static List<PracticeDay> merge(List<PracticeDay> a, List<PracticeDay> b) {
    final byDate = <DateTime, List<int>>{}; // [枚数, 合計分]
    for (final day in [...a, ...b]) {
      final d = DateTime(day.date.year, day.date.month, day.date.day);
      final acc = byDate.putIfAbsent(d, () => [0, 0]);
      acc[0] += day.uploadCount;
      acc[1] += day.totalMinutes;
    }
    return [
      for (final e in byDate.entries)
        PracticeDay(
          date: e.key,
          uploadCount: e.value[0],
          totalMinutes: e.value[1],
        ),
    ];
  }
}
