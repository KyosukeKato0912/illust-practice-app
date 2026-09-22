// ══════════════════════════════════════════════════════════
// 習慣化サポート テストデータ
//
// 成長記録機能が実装されるまでの仮データ。
// 成長記録実装後はこのファイルを削除し、
// HabitRecord（Hive）から取得したデータに差し替える。
//
// ■ データ追加方法
//   HabitTestRecord(id: 'xxx', date: DateTime(yyyy, m, d), workMinutes: nn)
//   を HabitTestData.records リストに追記する。
//   同一日付を複数登録すると作業時間合計に加算される。
// ══════════════════════════════════════════════════════════

// ──
//データ 1件分のモデル ────────────────────────────
class HabitTestRecord {
  final String id;
  final DateTime date;

  /// 作業時間（分）。0 以上の整数。
  final int workMinutes;

  HabitTestRecord({
    required this.id,
    required this.date,
    required this.workMinutes,
  });
}

// ── テストデータ一覧 ──────────────────────────────────────
abstract class HabitTestData {
  static final List<HabitTestRecord> records = [
    HabitTestRecord(
      id: 'test_001',
      date: DateTime(2026, 6, 1),
      workMinutes: 30,
    ),
    HabitTestRecord(
      id: 'test_002',
      date: DateTime(2026, 6, 1),
      workMinutes: 15,
    ),
    HabitTestRecord(
      id: 'test_003',
      date: DateTime(2026, 6, 2),
      workMinutes: 20,
    ),
    HabitTestRecord(
      id: 'test_004',
      date: DateTime(2026, 6, 4),
      workMinutes: 0, // 作業時間未入力の場合は 0 を登録
    ),
    HabitTestRecord(
      id: 'test_005',
      date: DateTime(2026, 6, 5),
      workMinutes: 45,
    ),
    HabitTestRecord(
      id: 'test_006',
      date: DateTime(2026, 6, 5),
      workMinutes: 30,
    ),
    HabitTestRecord(
      id: 'test_007',
      date: DateTime(2026, 6, 7),
      workMinutes: 10,
    ),
    // ── 連続記録の色分け検証用データ（21日分）────────────
    // 4/26〜5/16まで21日間連続。今日（実行時点の現在日）が
    // これより後であれば、5/16時点で連続日数が21日に達し、
    // 4/26〜5/16の区間全体が濃い黄色になる想定。
    HabitTestRecord(
        id: 'test_008', date: DateTime(2026, 4, 26), workMinutes: 20),
    HabitTestRecord(
        id: 'test_009', date: DateTime(2026, 4, 27), workMinutes: 20),
    HabitTestRecord(
        id: 'test_010', date: DateTime(2026, 4, 28), workMinutes: 20),
    HabitTestRecord(
        id: 'test_011', date: DateTime(2026, 4, 29), workMinutes: 20),
    HabitTestRecord(
        id: 'test_012', date: DateTime(2026, 4, 30), workMinutes: 20),
    HabitTestRecord(
        id: 'test_013', date: DateTime(2026, 5, 1), workMinutes: 20),
    HabitTestRecord(
        id: 'test_014', date: DateTime(2026, 5, 2), workMinutes: 20),
    HabitTestRecord(
        id: 'test_015', date: DateTime(2026, 5, 3), workMinutes: 20),
    HabitTestRecord(
        id: 'test_016', date: DateTime(2026, 5, 4), workMinutes: 20),
    HabitTestRecord(
        id: 'test_017', date: DateTime(2026, 5, 5), workMinutes: 20),
    HabitTestRecord(
        id: 'test_018', date: DateTime(2026, 5, 6), workMinutes: 20),
    HabitTestRecord(
        id: 'test_019', date: DateTime(2026, 5, 7), workMinutes: 20),
    HabitTestRecord(
        id: 'test_020', date: DateTime(2026, 5, 8), workMinutes: 20),
    HabitTestRecord(
        id: 'test_021', date: DateTime(2026, 5, 9), workMinutes: 20),
    HabitTestRecord(
        id: 'test_022', date: DateTime(2026, 5, 10), workMinutes: 20),
    HabitTestRecord(
        id: 'test_023', date: DateTime(2026, 5, 11), workMinutes: 20),
    HabitTestRecord(
        id: 'test_024', date: DateTime(2026, 5, 12), workMinutes: 20),
    HabitTestRecord(
        id: 'test_025', date: DateTime(2026, 5, 13), workMinutes: 20),
    HabitTestRecord(
        id: 'test_026', date: DateTime(2026, 5, 14), workMinutes: 20),
    HabitTestRecord(
        id: 'test_027', date: DateTime(2026, 5, 15), workMinutes: 20),
    HabitTestRecord(
        id: 'test_028', date: DateTime(2026, 5, 16), workMinutes: 20),
  ];
}
