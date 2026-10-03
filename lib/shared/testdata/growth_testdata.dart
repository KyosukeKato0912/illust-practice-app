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
//     （growthDataSourceModeProvider が test/merged の間、Hiveの代わりに
//       （mergedの場合はHiveと合わせて）こちらを使う）
//   ・features/habit/ui/habit_main_screen.dart
//     （habitDataSourceModeProvider が test/merged の間、growthProviderの
//       代わりに（mergedの場合は合わせて）こちらを直接参照する。growth側
//       の設定とは独立して切替可能）
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
// ── データ構成 ──────────────────────────────────────────
// 「いつからいつまで・1日あたり何枚・各何分」は [GrowthTestDataConfig]
// として メンテナンス画面（features/maintenance/ui/maintenance_screen.dart）
// から指定できる。指定された期間の全日について、指定枚数ぶんの
// レコードを機械的に生成する（1日あたり複数枚の場合は連番で区別）。
// 設定はメンテナンス画面の他の項目と同様にどこにも永続化しない
// （アプリ再起動で必ず [GrowthTestDataConfig.initial] に戻る）。
// ══════════════════════════════════════════════════════════

/// テストデータ生成条件。
/// [startDate]〜[endDate] は日付のみ（時刻は無視）で、両端を含む。
class GrowthTestDataConfig {
  final DateTime startDate;
  final DateTime endDate;
  final int countPerDay;
  final int minutesPerEntry;

  const GrowthTestDataConfig({
    required this.startDate,
    required this.endDate,
    required this.countPerDay,
    required this.minutesPerEntry,
  });

  /// リリース時の初期値：今日を含む過去25日間、1日1枚・20分。
  /// （継続日数マイルストーン21日をまたぐため、継続カレンダーの
  /// 濃い色表示の確認にそのまま使える）
  factory GrowthTestDataConfig.initial() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return GrowthTestDataConfig(
      startDate: today.subtract(const Duration(days: 24)),
      endDate: today,
      countPerDay: 1,
      minutesPerEntry: 20,
    );
  }

  GrowthTestDataConfig copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? countPerDay,
    int? minutesPerEntry,
  }) {
    return GrowthTestDataConfig(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      countPerDay: countPerDay ?? this.countPerDay,
      minutesPerEntry: minutesPerEntry ?? this.minutesPerEntry,
    );
  }
}

class GrowthTestDataConfigNotifier extends StateNotifier<GrowthTestDataConfig> {
  GrowthTestDataConfigNotifier() : super(GrowthTestDataConfig.initial());

  void setValue(GrowthTestDataConfig value) => state = value;

  /// 【検証用】メンテナンス画面の「初期状態に戻す」から呼ばれる。
  void resetToDefault() => state = GrowthTestDataConfig.initial();
}

final growthTestDataConfigProvider =
    StateNotifierProvider<GrowthTestDataConfigNotifier, GrowthTestDataConfig>(
        (ref) {
  return GrowthTestDataConfigNotifier();
});

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

  /// [config] の条件（期間・1日あたりの枚数・所要時間）に従って
  /// テストデータ本体を組み立てる（非同期：ダミー画像のコピーを含む）。
  /// UIからは直接呼ばず、[growthTestDataProvider] 経由で参照すること
  /// （結果がキャッシュされ、コピー処理が1回で済む）。
  ///
  /// [config.startDate] が [config.endDate] より後の場合は空リストを
  /// 返す（メンテナンス画面側でも同条件は決定前に弾くが、念のため）。
  static Future<List<GrowthRecord>> buildRecords(
    GrowthTestDataConfig config,
  ) async {
    final start = DateTime(
        config.startDate.year, config.startDate.month, config.startDate.day);
    final end = DateTime(
        config.endDate.year, config.endDate.month, config.endDate.day);
    if (end.isBefore(start)) return const [];

    final dummyImagePath = await _resolveDummyImagePath();
    final list = <GrowthRecord>[];

    for (var date = start;
        !date.isAfter(end);
        date = date.add(const Duration(days: 1))) {
      final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}'
          '${date.day.toString().padLeft(2, '0')}';
      for (var serial = 1; serial <= config.countPerDay; serial++) {
        list.add(GrowthRecord(
          id: 'test-$dateStr-$serial',
          imagePath: dummyImagePath,
          date: date,
          serialNumber: serial,
          durationMin: config.minutesPerEntry,
        ));
      }
    }

    return list;
  }
}

// ── Provider 定義 ─────────────────────────────────────────
// buildRecords() の結果（ダミー画像コピー含む）を、生成条件
// （growthTestDataConfigProvider）が変わるたびに作り直してキャッシュする。
// growth_provider.dart（ref.read(...future)）と
// habit_main_screen.dart（ref.watch）の両方から参照される。
final growthTestDataProvider = FutureProvider<List<GrowthRecord>>((ref) {
  final config = ref.watch(growthTestDataConfigProvider);
  return GrowthTestData.buildRecords(config);
});
