import '../../../core/constants/app_strings.dart';
import '../../../core/services/notification_service.dart';

// ══════════════════════════════════════════════════════════
// メンテナンス画面「通知テスト」の窓口（state/ 層）
//
// UI が NotificationService を直接 import しないための薄いラッパー。
// テスト通知の登録を依頼し、結果を画面に出すメッセージに変換して返す。
// 実際の通知予約（作業開始促進・復帰促進）には影響しない。
// ══════════════════════════════════════════════════════════
abstract class MaintenanceNotificationController {
  /// 作業開始促進通知を1分後に1回だけ送る。返り値は画面に表示するメッセージ。
  static Future<String> scheduleReminderTest() async =>
      _toMessage(await NotificationService.scheduleTestReminder());

  /// 復帰促進通知を1分後に1回だけ送る。返り値は画面に表示するメッセージ。
  static Future<String> scheduleComebackTest() async =>
      _toMessage(await NotificationService.scheduleTestComeback());

  static String _toMessage(NotificationTestResult result) {
    switch (result.status) {
      case NotificationTestStatus.scheduled:
        final at = result.scheduledAt!;
        final hh = at.hour.toString().padLeft(2, '0');
        final mm = at.minute.toString().padLeft(2, '0');
        final ss = at.second.toString().padLeft(2, '0');
        final mode = result.usedExactAlarm
            ? AppStrings.maintenanceNotificationExactOn
            : AppStrings.maintenanceNotificationExactOff;
        return '$hh:$mm:$ss${AppStrings.maintenanceNotificationScheduledSuffix}$mode';
      case NotificationTestStatus.permissionDenied:
        return AppStrings.maintenanceNotificationPermissionDenied;
      case NotificationTestStatus.unsupported:
        return AppStrings.maintenanceNotificationUnsupported;
      case NotificationTestStatus.failed:
        return AppStrings.maintenanceNotificationFailed;
    }
  }
}
