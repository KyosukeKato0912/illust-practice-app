import 'dart:typed_data';
import '../domain/growth_record.dart';
import 'growth_pdf_service.dart';

// ══════════════════════════════════════════════════════════
// GrowthPdfController
//
// 成長記録PDFの生成窓口（state層）。
// UI（growth_main_screen / upload_complete_screen）が
// GrowthPdfService（growth固有のPDF生成処理）を直接 import しないよう、
// UI からは state 層の Controller のみを参照する構成にするための
// 薄いラッパー。単一操作で完結し画面をまたいで状態を保持しないため、
// Riverpodは使わず static メソッドのみとする。
//
// ・並び順は渡された records の順序のまま PDF に反映される
//   （GrowthPdfService 側で再ソートしない）
// ・PDFの保存（file_picker）は従来どおり呼び出し側が行う
// ══════════════════════════════════════════════════════════
abstract class GrowthPdfController {
  /// [records] をPDF化してバイト列を返す。
  /// [onProgress] には 0〜100 の進捗（%）が通知される。
  static Future<Uint8List> build(
    List<GrowthRecord> records, {
    void Function(int percent)? onProgress,
  }) =>
      GrowthPdfService.build(records, onProgress: onProgress);

  /// 保存時のファイル名（拡張子 .pdf 込み）を返す。
  static String buildFileName(DateTime now) =>
      GrowthPdfService.buildFileName(now);
}
