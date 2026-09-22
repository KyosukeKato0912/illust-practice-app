import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/growth/domain/growth_record.dart';
import '../constants/app_strings.dart';
import '../utils/date_utils.dart';

// ══════════════════════════════════════════════════════════
// GrowthPdfService
//
// 成長記録の画像一覧をPDF化する。
//
// ページ構成：
//   1ページ目 … 表紙（タイトル・対象期間・対象枚数）
//   2ページ目以降 … サムネグリッド（3列×4行 = 12枚/ページ、
//                   各サムネの上にファイル名を表示）
// 全ページ共通：
//   ヘッダー（上部）… growthPdfHeaderTitle固定文言
//   フッター（下部）… ページ番号（表紙を含めた通し番号）
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
// UIからは build() のみを呼び出し、Documentの組み立て・画像読み込みは
// このサービス内に閉じる。
// ══════════════════════════════════════════════════════════
abstract class GrowthPdfService {
  static const int _columns = 3;
  static const int _rows = 4;
  static const int _perPage = _columns * _rows;

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
  /// 内部で日付昇順に並び替えてから表紙の対象期間・グリッドの並びを決める。
  static Future<Uint8List> build(List<GrowthRecord> records) async {
    final regularFont = await PdfGoogleFonts.notoSansJPRegular();
    final boldFont = await PdfGoogleFonts.notoSansJPBold();
    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    final doc = pw.Document(theme: theme);

    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
    final periodLabel = sorted.isEmpty
        ? ''
        : '${AppDateUtils.formatYMD(sorted.first.date)} 〜 '
            '${AppDateUtils.formatYMD(sorted.last.date)}';
    final chunks = _chunk(sorted, _perPage);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          _marginLeftRight,
          _marginTop,
          _marginLeftRight,
          _marginBottom,
        ),
        header: (context) => _buildHeader(),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Container(
            height: _contentHeight,
            child: _buildCover(
              periodLabel: periodLabel,
              count: sorted.length,
            ),
          ),
          for (final chunk in chunks) ...[
            pw.NewPage(),
            pw.Container(height: _contentHeight, child: _buildGrid(chunk)),
          ],
        ],
      ),
    );

    return doc.save();
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

  // ── ヘッダー（全ページ共通） ─────────────────────────────
  static pw.Widget _buildHeader() {
    return pw.Container(
      height: _headerHeight,
      alignment: pw.Alignment.center,
      child: pw.Text(
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
  }) {
    return pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            AppStrings.growthPdfHeaderTitle,
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 28),
          if (periodLabel.isNotEmpty) ...[
            pw.Text(periodLabel, style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 8),
          ],
          pw.Text(
            '${AppStrings.growthPdfCoverCountPrefix}$count'
            '${AppStrings.growthPdfCoverCountSuffix}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  // ── サムネグリッド（3列×4行、余りは空セルで埋める） ──────
  static pw.Widget _buildGrid(List<GrowthRecord> records) {
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
                  ? _buildCell(records[index])
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
  static pw.Widget _buildCell(GrowthRecord record) {
    final fileName = record.imagePath.split('/').last;
    final bytes = File(record.imagePath).readAsBytesSync();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          fileName,
          style: const pw.TextStyle(fontSize: 6),
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
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
          ),
        ),
      ],
    );
  }
}
