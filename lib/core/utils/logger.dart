import 'package:flutter/foundation.dart' show debugPrint;
import '../config/app_config.dart';

// ══════════════════════════════════════════════════════════
// AppLogger
//
// デバッグログの出力窓口。debugPrint を直接呼ばず、必ずここを経由する。
//
// 出力のON/OFFは AppConfig.enableDebugLog（const）で切り替える。
// 既定は false で、通常は何も出力しない。原因調査が必要になったら
// true に変更して再ビルドすれば、既存のログ呼び出しがそのまま復活する。
//
// ⚠ ログ出力のためだけに行う処理（プラグインへの問い合わせ等）は
//   AppLogger.enabled で囲み、OFFのときに余計な処理を走らせないこと。
// ══════════════════════════════════════════════════════════
abstract class AppLogger {
  AppLogger._();

  /// ログ出力が有効か。
  static bool get enabled => AppConfig.enableDebugLog;

  /// [message] を出力する（無効時は何もしない）。
  static void log(String message) {
    if (!enabled) return;
    debugPrint(message);
  }
}
