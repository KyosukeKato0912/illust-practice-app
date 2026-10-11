import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/utils/date_utils.dart';

// ══════════════════════════════════════════════════════════
// GrowthStreakUtils
//
// 「指定日を含む連続記録日数（span）」と「その日数に対応する継続
// カレンダーの色」を計算する純粋関数群。
//
// 元々は features/growth/ui/upload_complete_screen.dart の
// _streakSpanAt / _streakColor にしか無かったロジックだが、
// アップロード完了時の演出アニメーション（花丸・色変え・メッセージ・
// PDFボタンのフェードイン）をどのタイミングで発生させるかを
// GrowthNotifier（state/growth_provider.dart）側でも判定する必要が
// あるため、両者から共通で使えるようdomain層に切り出した。
// ══════════════════════════════════════════════════════════
abstract class GrowthStreakUtils {
  /// [date] を含む連続記録区間の「総日数」を計算する。
  /// [date] 自体に記録がない場合は 0 を返す。
  /// 未来日（DateTime.now() より後）は連続判定に含めない。
  static int spanAt(DateTime date, Set<String> recordedDateKeys) {
    final key = AppDateUtils.dateKey(date);
    if (!recordedDateKeys.contains(key)) return 0;

    int backCount = 0;
    DateTime cursor = date;
    while (recordedDateKeys.contains(AppDateUtils.dateKey(cursor))) {
      backCount++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    int forwardCount = 0;
    cursor = date.add(const Duration(days: 1));
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    while (!cursor.isAfter(todayDate) &&
        recordedDateKeys.contains(AppDateUtils.dateKey(cursor))) {
      forwardCount++;
      cursor = cursor.add(const Duration(days: 1));
    }

    return backCount + forwardCount;
  }

  /// 連続記録日数から継続カレンダーのセル色を決める
  /// （白 → 薄い黄色 → 濃い黄色）。
  static Color colorForSpan(int span) {
    if (span < 2) return Colors.white;
    if (span < AppValues.growthStreakDarkThresholdDays) {
      return AppColors.growthStreakLight;
    }
    return AppColors.growthStreakDark;
  }

  /// [date] のセル色（[spanAt] と [colorForSpan] をまとめて呼ぶ）。
  static Color colorAt(DateTime date, Set<String> recordedDateKeys) =>
      colorForSpan(spanAt(date, recordedDateKeys));
}
