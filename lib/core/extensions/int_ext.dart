import '../constants/app_strings.dart';

// ══════════════════════════════════════════════════════════
// int 拡張
// ══════════════════════════════════════════════════════════
extension IntExt on int {
  /// 秒数を「X秒」または「X分」「X分Y秒」の表示文字列に変換する。
  ///
  /// 例:
  ///   45    → '45 秒'
  ///   60    → '1 分'
  ///   90    → '1 分 30 秒'
  ///   600   → '10 分'
  ///
  /// タイマー表示・設定サマリー等、複数箇所で使用する。
  String toDisplayDuration() {
    if (this < 60) return '$this ${AppStrings.unitSecond}';
    final m = this ~/ 60;
    final s = this % 60;
    return s == 0
        ? '$m ${AppStrings.unitMinute}'
        : '$m ${AppStrings.unitMinute} $s ${AppStrings.unitSecond}';
  }

  /// 秒数を 'HH:MM:SS' 形式に変換する（総作業時間等の表示用）。
  ///
  /// 例:
  ///   45   → '00:00:45'
  ///   3600 → '01:00:00'
  ///   5430 → '01:30:30'
  String toHHMMSS() {
    final h = (this ~/ 3600).toString().padLeft(2, '0');
    final m = ((this % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (this % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
