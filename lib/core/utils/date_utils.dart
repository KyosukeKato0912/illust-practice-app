// ══════════════════════════════════════════════════════════
// 日付フォーマット・週計算ヘルパー
//
// 機能固有のロジックを持たない純粋な日付ユーティリティ。
// UI層（habit_main_screen.dart 等）に直接実装せず、
// ここに集約することで複数箇所での重複実装を防ぐ。
// ══════════════════════════════════════════════════════════
abstract class AppDateUtils {
  /// 'yyyy/M/d' 形式の文字列に変換する（画面表示用）
  ///
  /// 例: DateTime(2026, 6, 1) → '2026/6/1'
  static String formatYMD(DateTime d) => '${d.year}/${d.month}/${d.day}';

  /// 'yyyy-MM-dd' 形式のキー文字列に変換する。
  /// 時刻差による不一致を防ぐため、Map・Setのキーとして使用する。
  ///
  /// 例: DateTime(2026, 6, 1) → '2026-06-01'
  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 指定日が属する週の月曜日を返す（時刻情報は00:00に正規化）
  static DateTime mondayOf(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }

  /// 指定した週の月曜日から7日分（月〜日）の日付リストを返す
  static List<DateTime> getWeekDates(DateTime monday) =>
      List.generate(7, (i) => monday.add(Duration(days: i)));
}
