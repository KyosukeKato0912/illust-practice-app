import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/growth_record.dart';

// ══════════════════════════════════════════════════════════
// GrowthPdfService
//
// 成長記録の画像一覧をPDF化する。
//
// ページ構成：
//   1ページ目 … 表紙（タイトル・キャッチコピー・対象期間・対象枚数）
//   2ページ目以降 … サムネグリッド（3列×4行 = 12枚/ページ、
//                   各サムネの上にファイル名を表示）
// ヘッダー／フッター：
//   ヘッダー（上部）… growthPdfHeaderTitle固定文言（表紙のみ非表示）
//   フッター（下部）… ページ番号（表紙を含めた通し番号、全ページ共通）
//
// 日本語フォントは端末やビルド環境にフォントファイルを同梱する代わりに
// printing パッケージの PdfGoogleFonts（Noto Sans JP）を実行時に取得して
// 使用する（初回はネットワークアクセスが発生し、以降はキャッシュされる）。
//
// ⚠ header/footer は pw.Page には存在せず、pw.MultiPage 専用のパラメータ。
//   ドキュメント全体を単一の pw.MultiPage として組み立て、表紙とグリッド
//   ページの間は pw.NewPage() で明示的に改ページする（公式ドキュメントの
//   「複数セクションをそれぞれ1ページに収める」パターンに準拠）。
//
// ⚠ pw.MultiPage の build: に渡すトップレベルの要素には高さの制約が
//   与えられない（オートページネーションのため）。そのため表紙・グリッドを
//   直接 pw.Expanded で包むと「incoming height constraints are
//   unbounded」で例外になる。ヘッダー／フッターの高さを固定値で自前管理し、
//   ページ本文の高さ（_contentHeight）を逆算したうえで、表紙・グリッドは
//   その固定高さの pw.Container で包む。Container が高さを確定させるため、
//   内部（_buildGrid など）で使っている pw.Expanded は問題なく機能する。
//
// ── 画像の縮小について（メモリ不足対策） ─────────────────
// 成長記録の画像は原寸（数MB）のまま保存されているが、PDF上のサムネは
// 4cm角程度のため、原寸のまま埋め込むと300枚で出力が数百MBになり、
// Dartヒープ（約256MB）を超えて「Out of Memory」になる（実機で確認済み）。
// そのため埋め込み前に flutter_image_compress（ネイティブ処理）で
// 長辺〜[_thumbMinSize]px・JPEG品質[_thumbQuality]に縮小・再圧縮する
// （1枚あたり数十KB。pdfパッケージはJPEGを再エンコードせずそのまま
// 埋め込むため軽い）。縮小は[_concurrency]枚ずつ非同期で行うため、
// UIスレッドを塞がず、進捗も通知できる。同じパスの画像は1回だけ縮小し、
// 同じImageProviderを使い回す（PDF内でも1つの画像として埋め込まれる）。
//
// UIからは build() のみを呼び出し、Documentの組み立て・画像読み込みは
// このサービス内に閉じる。
// ══════════════════════════════════════════════════════════
abstract class GrowthPdfService {
  static const int _columns = 3;
  static const int _rows = 4;
  static const int _perPage = _columns * _rows;

  // サムネ用に縮小する際の設定（A4上のセルは約5.9cm×5.3cm＝約170dpiで
  // 480px程度あれば十分）。
  static const int _thumbMinSize = 480;
  static const int _thumbQuality = 75;
  static const int _concurrency = 4;

  // 進捗表示：画像の縮小が完了した時点を何％とみなすか（残りはPDFの
  // 組み立て・書き出し）。
  static const int _progressImagePercent = 90;

  // ページ余白・ヘッダー／フッターの高さは固定値として自前管理する
  // （_buildHeader/_buildFooter もこの値に合わせて描画する）。
  static const double _marginLeftRight = 28;
  static const double _marginTop = 32;
  static const double _marginBottom = 32;
  static const double _headerHeight = 36;
  static const double _footerHeight = 28;

  /// 表紙・グリッドに割り当てられる本文の高さ（ヘッダー／フッターを除いた分）。
  static double get _contentHeight =>
      PdfPageFormat.a4.height -
      _marginTop -
      _marginBottom -
      _headerHeight -
      _footerHeight;

  /// [records] は成長記録の全件をそのまま渡す想定（絞込の影響は受けない）。
  /// 並び順は渡された [records] の順序をそのまま踏襲する（内部では並べ替えない）。
  /// 成長記録メイン画面側のソート設定で並べた一覧を渡すことで、
  /// 画面と同じ並びでPDFが出力される。表紙の対象期間は並び順に依存せず、
  /// 日付の最小〜最大から決める。
  ///
  /// [onProgress] には全体の進捗（0〜100の整数％）が通知される。
  /// 画像の縮小（時間の大半を占める）を0〜[_progressImagePercent]％、
  /// その後のPDFの組み立て・書き出しの完了を100％として扱う。
  static Future<Uint8List> build(
    List<GrowthRecord> records, {
    void Function(int percent)? onProgress,
  }) async {
    onProgress?.call(0);
    final regularFont = await PdfGoogleFonts.notoSansJPRegular();
    final boldFont = await PdfGoogleFonts.notoSansJPBold();
    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    final doc = pw.Document(theme: theme);

    // 並び順は呼び出し元が渡した順序のまま（再ソートしない）
    final ordered = records;
    String periodLabel = '';
    if (ordered.isNotEmpty) {
      // 並び順に依存しないよう、日付の最小・最大から期間を求める
      var oldest = ordered.first.date;
      var newest = ordered.first.date;
      for (final r in ordered) {
        if (r.date.isBefore(oldest)) oldest = r.date;
        if (r.date.isAfter(newest)) newest = r.date;
      }
      periodLabel = '${AppDateUtils.formatYMD(oldest)} 〜 '
          '${AppDateUtils.formatYMD(newest)}';
    }
    final totalDurationMin = ordered.fold<int>(
        0, (sum, r) => sum + (r.durationMin ?? 0));
    final chunks = _chunk(ordered, _perPage);
    final thumbnails = await _prepareThumbnails(
      ordered,
      onProgress == null
          ? null
          : (done, total) => onProgress(
              total == 0 ? _progressImagePercent : done * _progressImagePercent ~/ total),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          _marginLeftRight,
          _marginTop,
          _marginLeftRight,
          _marginBottom,
        ),
        header: (context) => _buildHeader(context),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Container(
            height: _contentHeight,
            child: _buildCover(
              periodLabel: periodLabel,
              count: ordered.length,
              totalDurationMin: totalDurationMin,
            ),
          ),
          for (final chunk in chunks) ...[
            pw.NewPage(),
            pw.Container(height: _contentHeight, child: _buildGrid(chunk, thumbnails)),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    onProgress?.call(100);
    return bytes;
  }

  /// 全レコードの画像をサムネ用に縮小し、パス→ImageProvider のMapで返す。
  /// 縮小に失敗した画像は null（セルは空枠になる）。
  static Future<Map<String, pw.MemoryImage?>> _prepareThumbnails(
    List<GrowthRecord> records,
    void Function(int done, int total)? onProgress,
  ) async {
    final paths = <String>{for (final r in records) r.imagePath}.toList();
    final result = <String, pw.MemoryImage?>{};
    onProgress?.call(0, paths.length);

    for (var i = 0; i < paths.length; i += _concurrency) {
      final batch = paths.sublist(
          i, (i + _concurrency < paths.length) ? i + _concurrency : paths.length);
      final images = await Future.wait(batch.map(_compressToThumbnail));
      for (var j = 0; j < batch.length; j++) {
        result[batch[j]] = images[j];
      }
      onProgress?.call(i + batch.length, paths.length);
    }
    return result;
  }

  static Future<pw.MemoryImage?> _compressToThumbnail(String path) async {
    try {
      final bytes = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: _thumbMinSize,
        minHeight: _thumbMinSize,
        quality: _thumbQuality,
        format: CompressFormat.jpeg,
      );
      if (bytes == null || bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('[GrowthPdfService] 画像の縮小に失敗しました: $path ($e)');
      return null;
    }
  }

  /// [Printing.sharePdf] に渡すファイル名（例：'成長記録_2026-06-01.pdf'）を組み立てる。
  static String buildFileName(DateTime now) {
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    // file_picker のsaveFile()には同名ファイル存在時の連番付与に
    // 既知の不具合があり、拡張子が壊れてしまう
    // （https://github.com/miguelpruivo/flutter_file_picker/issues/1598）。
    // 日付だけだと1日に複数回保存した際に衝突しやすいため、秒まで含めて
    // 衝突自体を避ける。
    return '${AppStrings.growthPdfFileNamePrefix}$y-$m-$d-$hh$mm$ss.pdf';
  }

  static List<List<GrowthRecord>> _chunk(List<GrowthRecord> list, int size) {
    final result = <List<GrowthRecord>>[];
    for (var i = 0; i < list.length; i += size) {
      final end = (i + size < list.length) ? i + size : list.length;
      result.add(list.sublist(i, end));
    }
    return result;
  }

  // ── ヘッダー（表紙を除く全ページ共通） ───────────────────
  // 表紙（1ページ目）はタイトル・キャッチコピーを独自に表示するため、
  // 上部ヘッダーの文言は表紙のみ非表示にする（高さは他ページと揃えたまま空にする）。
  static pw.Widget _buildHeader(pw.Context context) {
    final isCover = context.pageNumber == 1;
    return pw.Container(
      height: _headerHeight,
      alignment: pw.Alignment.center,
      child: isCover
          ? null
          : pw.Text(
              AppStrings.growthPdfHeaderTitle,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
    );
  }

  // ── フッター（全ページ共通：ページ番号） ─────────────────
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      height: _footerHeight,
      alignment: pw.Alignment.center,
      child: pw.Text(
        '${context.pageNumber}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }

  // ── 表紙 ────────────────────────────────────────────────
  static pw.Widget _buildCover({
    required String periodLabel,
    required int count,
    required int totalDurationMin,
  }) {
    final hours = totalDurationMin ~/ 60;
    final minutes = totalDurationMin % 60;
    final durationText = totalDurationMin == 0
        ? AppStrings.growthPdfCoverTotalDurationNone
        : '$hours${AppStrings.growthPdfCoverTotalDurationHourUnit}'
            '$minutes${AppStrings.growthPdfCoverTotalDurationMinuteUnit}';
    final summaryLabel =
        '${AppStrings.growthPdfCoverTotalDurationPrefix}$durationText'
        '　${AppStrings.growthPdfCoverCountPrefix}$count'
        '${AppStrings.growthPdfCoverCountSuffix}';

    return pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            AppStrings.growthPdfHeaderTitle,
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            AppStrings.growthPdfCoverCatchCopy,
            style: const pw.TextStyle(fontSize: 20, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 28),
          if (periodLabel.isNotEmpty) ...[
            pw.Text(periodLabel, style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 8),
          ],
          pw.Text(
            summaryLabel,
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  // ── サムネグリッド（3列×4行、余りは空セルで埋める） ──────
  static pw.Widget _buildGrid(
    List<GrowthRecord> records,
    Map<String, pw.MemoryImage?> thumbnails,
  ) {
    final rowWidgets = <pw.Widget>[];
    for (var r = 0; r < _rows; r++) {
      final cells = <pw.Widget>[];
      for (var c = 0; c < _columns; c++) {
        final index = r * _columns + c;
        cells.add(
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: index < records.length
                  ? _buildCell(records[index], thumbnails[records[index].imagePath])
                  : pw.Container(),
            ),
          ),
        );
      }
      rowWidgets.add(
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: rowWidgets,
    );
  }

  // ── サムネ1件分（ファイル名 + 画像） ─────────────────────
  static pw.Widget _buildCell(GrowthRecord record, pw.MemoryImage? image) {
    final fileName = record.imagePath.split('/').last;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          fileName,
          style: const pw.TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 3),
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
            ),
            child: image == null
                ? pw.Container()
                : pw.Image(image, fit: pw.BoxFit.cover),
          ),
        ),
      ],
    );
  }
}
