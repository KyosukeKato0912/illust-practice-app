import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/growth/domain/growth_record.dart';

// ══════════════════════════════════════════════════════════
// GrowthTestData / growthTestDataProvider
//
// 成長記録（GrowthRecord）は現在、成長記録・習慣化サポート両方の
// 継続カレンダーが参照する唯一のデータソースである。そのため
// テストデータも features/growth 配下ではなく、両機能から等しく
// 参照できる shared/ 配下に置く。
//
// 参照側：
//   ・features/growth/state/growth_provider.dart
//     （GrowthConfig.useTestData が true の間、Hiveの代わりにこちらを使う）
//   ・features/habit/ui/habit_main_screen.dart
//     （HabitConfig.useTestData が true の間、growthProviderの代わりに
//       こちらを直接参照する。growth側の設定とは独立して切替可能）
//
// ── ダミー画像について ──────────────────────────────────
// GrowthRecord.imagePath は「端末ローカルの実ファイルパス」を前提と
// しており（成長記録メイン画面等が File(imagePath) で読み込むため）、
// Flutterのアセットパス（assets/...）をそのまま渡すことはできない。
// そのため、assets/images/dummy/growth_dummy.png を起動時に一度だけ
// 端末ローカル（アプリ専用ドキュメントディレクトリ）にコピーし、
// そのコピー先の実パスを全テストレコードで共有する。
// コピー処理は非同期のため、[buildRecords] は Future を返す
// （[growthTestDataProvider] 経由で結果をキャッシュして参照する）。
//
// ── データ構成（継続カレンダーの配色確認用） ──────────────
// 3つの区間を「今日」からの相対日数で動的に生成する（固定の日付
// リテラルにすると日が経つにつれ「今日」との位置関係がずれるため）。
// 区間同士は必ず1日以上の空白日を挟み、連続区間が意図せず
// 繋がらないようにしている。
//
//   ① 濃い黄色区間：今日の1〜25日前（25日間連続）
//      → 区間長25 ≧ しきい値21 のため、区間全体が濃い黄色になる。
//      → 直近（1〜数日前）を含むため、習慣化サポートの週表示・
//        成長記録の月表示のどちらでもナビゲーションなしで確認しやすい。
//   （空白：26日前）
//   ② 薄い黄色区間：今日の27〜28日前（2日間連続）
//      → 区間長2（2以上21未満）のため、薄い黄色になる。
//   （空白：29日前）
//   ③ 白：今日の30日前（孤立した1日）
//      → 前後に記録がないため区間長1、白のまま。
// ══════════════════════════════════════════════════════════
abstract class GrowthTestData {
  static const String _dummyAssetPath =
      'assets/images/dummy/growth_dummy.png';
  static const String _dummyFileName = 'growth_dummy_test.png';

  /// アセットからコピーしたダミー画像の実パス（アプリ起動中キャッシュ）。
  static String? _cachedDummyImagePath;

  /// assets/images/dummy/growth_dummy.png を端末ローカルにコピーし、
  /// そのファイルパスを返す。既にコピー済みならキャッシュを返す
  /// （アプリ起動中に複数回コピーしない）。
  static Future<String> _resolveDummyImagePath() async {
    final cached = _cachedDummyImagePath;
    if (cached != null) return cached;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_dummyFileName');

    if (!await file.exists()) {
      final byteData = await rootBundle.load(_dummyAssetPath);
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      await file.writeAsBytes(bytes, flush: true);
    }

    _cachedDummyImagePath = file.path;
    return file.path;
  }

  /// テストデータ本体を組み立てる（非同期：ダミー画像のコピーを含むため）。
  /// UIからは直接呼ばず、[growthTestDataProvider] 経由で参照すること
  /// （結果がキャッシュされ、コピー処理が1回で済む）。
  static Future<List<GrowthRecord>> buildRecords() async {
    final dummyImagePath = await _resolveDummyImagePath();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime daysAgo(int n) => today.subtract(Duration(days: n));

    final list = <GrowthRecord>[];

    void addDay(DateTime date, {int? durationMin}) {
      list.add(GrowthRecord(
        id: 'test-${date.year}${date.month.toString().padLeft(2, '0')}'
            '${date.day.toString().padLeft(2, '0')}',
        imagePath: dummyImagePath,
        date: date,
        serialNumber: 1,
        durationMin: durationMin,
      ));
    }

    // ① 濃い黄色：1〜25日前の25日間連続
    for (var i = 1; i <= 25; i++) {
      addDay(daysAgo(i), durationMin: 25);
    }

    // （26日前は空白）

    // ② 薄い黄色：27〜28日前の2日間連続
    addDay(daysAgo(27), durationMin: 15);
    addDay(daysAgo(28), durationMin: 15);

    // （29日前は空白）

    // ③ 白：30日前の孤立した1日
    addDay(daysAgo(30), durationMin: 10);

    return list;
  }
}

// ── Provider 定義 ─────────────────────────────────────────
// buildRecords() の結果（ダミー画像コピー含む）をアプリ全体で
// キャッシュする。growth_provider.dart（ref.read(...future)）と
// habit_main_screen.dart（ref.watch）の両方から参照される。
final growthTestDataProvider =
    FutureProvider<List<GrowthRecord>>((ref) => GrowthTestData.buildRecords());
