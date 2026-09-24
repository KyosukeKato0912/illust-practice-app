import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

// ══════════════════════════════════════════════════════════
// 通知サービス
//
// ■ 即時通知
//   showWorkFinished()  : 作業終了 → 休憩開始（軽い振動＋タイマー画面内バナー / ネイティブ通知）
//   showBreakFinished() : 休憩終了 → 作業開始（軽い振動＋タイマー画面内バナー / ネイティブ通知）
//
// ■ 毎日スケジュール通知
//   scheduleReminder(hour, minute) : 毎日指定時刻に作業開始を促す通知を登録
//       正確なアラーム権限があれば時刻ちょうど（exact）、無ければ省電力に
//       任せるモード（inexact・数分ずれることがある）で登録する
//   cancelReminder()               : 作業開始促進通知を解除
//   canScheduleExactAlarms()       : 正確なアラーム権限の有無を確認
//   requestExactAlarmPermission()  : 設定画面（アラームとリマインダー）へ誘導
//
// ■ 復帰促進通知
//   scheduleComebackIfNeeded(lastPracticeDate, thresholdDays)
//     : 最終練習日から thresholdDays 日後の正午に1回だけ通知を登録。
//       既に閾値を超えていれば即日正午（過去なら翌日）に登録。
//   cancelComeback() : 復帰促進通知を解除
// ══════════════════════════════════════════════════════════
class NotificationService {
  NotificationService._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final _plugin = FlutterLocalNotificationsPlugin();

  // ── 通知チャンネル ────────────────────────────────────
  // チャンネルIDは識別子。ユーザーに見える名称・説明は AppStrings で管理する。
  static const _timerChannelId = 'habit_timer';
  static const _reminderChannelId = 'habit_reminder_v2';

  // ── 通知ID ───────────────────────────────────────────
  static const _workFinishedId = 1001;
  static const _breakFinishedId = 1002;
  static const _reminderId = 2001;
  static const _comebackId = 2002;

  // ── 通知テキスト ──────────────────────────────────────
  // タイトル・本文は AppStrings（notification〜）で管理する。

  // ── 初期化 ────────────────────────────────────────────
  static Future<void> initialize() async {
    if (kIsWeb) return;

    tz_data.initializeTimeZones();
    try {
      // 3秒応答がなければ強制タイムアウトさせ、安全にキャッチへ移行します
      final timezoneInfo = await FlutterTimezone.getLocalTimezone()
          .timeout(const Duration(seconds: 3));

      final timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint(
          '[NotificationService] timezone set to $timeZoneName (tz.local=${tz.local.name})');
    } catch (e, st) {
      debugPrint(
          '[NotificationService] timezone lookup failed or timed out: $e');
      // フリーズ時やエラー時は、安全なフォールバックとして日本時間（Asia/Tokyo）を強制適用
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
        debugPrint('[NotificationService] Fallback to Asia/Tokyo applied.');
      } catch (innerException) {
        debugPrint('[NotificationService] Fallback failed: $innerException');
      }
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    // プラグインと通知チャンネルの登録を確実に完了させる
    await _plugin.initialize(initSettings);
    debugPrint(
        '[NotificationService] FlutterLocalNotificationsPlugin initialized completely!');

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidPlugin?.requestNotificationsPermission();
    debugPrint(
        '[NotificationService] notifications permission granted: $granted');

    // ⬇️ 【ここから追記】OSに対して通知チャンネルを強制的に直接登録する処理
    try {
      if (androidPlugin != null) {
        const androidChannel = AndroidNotificationChannel(
          'habit_reminder_v2', // コード内で指定しているチャンネルIDと完全に一致させる
          AppStrings.notificationReminderChannelName,
          description: AppStrings.notificationReminderChannelDesc,
          importance: Importance.high, // 必ずHIGH（ポップアップ表示）を指定
          playSound: true,
        );

        // OSへチャンネルを直接作成・登録要求
        await androidPlugin.createNotificationChannel(androidChannel);
        debugPrint(
            '[NotificationService] AndroidNotificationChannel created forcibly by code!');
      }
    } catch (e) {
      debugPrint('[NotificationService] Forcible channel creation failed: $e');
    }
    // ⬆️ 【ここまで追記】

    // Dart側から見て、OSに実際に登録されているチャンネル一覧を確認する。
    // ここに"作業開始促進"が出ていなければ、上のcreateNotificationChannel
    // 自体が何らかの理由で反映されていないことになる。
    try {
      final channels = await androidPlugin?.getNotificationChannels();
      debugPrint('[NotificationService] registered channels: '
          '${channels?.map((c) => '${c.id}:${c.name}(importance=${c.importance})').toList()}');
    } catch (e) {
      debugPrint('[NotificationService] getNotificationChannels failed: $e');
    }

    // 通知が全体として有効かどうか（設定→アプリ→通知のトグル）も確認
    try {
      final enabled = await androidPlugin?.areNotificationsEnabled();
      debugPrint('[NotificationService] areNotificationsEnabled: $enabled');
    } catch (e) {
      debugPrint('[NotificationService] areNotificationsEnabled failed: $e');
    }
  }

  // ── 作業終了（→ 休憩開始）通知 ────────────────────────
  static Future<void> showWorkFinished() async {
    HapticFeedback.lightImpact();
    if (kIsWeb) {
      _showWebBanner(
          icon: Icons.coffee_outlined,
          title: AppStrings.notificationWorkFinishedTitle,
          message: AppStrings.notificationWorkFinishedMessage);
      return;
    }
    await _showNativeNow(
        id: _workFinishedId,
        channelId: _timerChannelId,
        channelName: AppStrings.notificationTimerChannelName,
        channelDesc: AppStrings.notificationTimerChannelDesc,
        title: AppStrings.notificationWorkFinishedTitle,
        message: AppStrings.notificationWorkFinishedMessage);
  }

  // ── 休憩終了（→ 作業開始）通知 ────────────────────────
  static Future<void> showBreakFinished() async {
    HapticFeedback.lightImpact();
    if (kIsWeb) {
      _showWebBanner(
          icon: Icons.play_circle_outline,
          title: AppStrings.notificationBreakFinishedTitle,
          message: AppStrings.notificationBreakFinishedMessage);
      return;
    }
    await _showNativeNow(
        id: _breakFinishedId,
        channelId: _timerChannelId,
        channelName: AppStrings.notificationTimerChannelName,
        channelDesc: AppStrings.notificationTimerChannelDesc,
        title: AppStrings.notificationBreakFinishedTitle,
        message: AppStrings.notificationBreakFinishedMessage);
  }

  // ── 正確なアラーム権限 ────────────────────────────────
  // Android 12+ では「アラームとリマインダー」の許可が必要で、
  // 特に Android 14+ の新規インストールでは既定でOFF。
  // Web・Android以外は確認不要のため true を返す。
  static Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb) return true;
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) return true;
      return await androidPlugin.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('[NotificationService] canScheduleExactAlarms failed: $e');
      return false;
    }
  }

  /// システムの設定画面（アラームとリマインダー）を開いて許可を求める。
  /// 設定画面から戻ったあとの許可状態を返す。
  static Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb) return true;
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) return true;
      return await androidPlugin.requestExactAlarmsPermission() ?? false;
    } catch (e) {
      debugPrint(
          '[NotificationService] requestExactAlarmPermission failed: $e');
      return false;
    }
  }

  // ── 作業開始促進：毎日スケジュール登録 ────────────────
  static Future<void> scheduleReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;

    debugPrint(
        '[NotificationService] scheduleReminder called: $hour:${minute.toString().padLeft(2, '0')}');

    await cancelReminder();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 指定時刻が既に過ぎていれば、翌日の同時刻から開始する
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    debugPrint(
        '[NotificationService] now=$now scheduled=$scheduled (tz.local=${tz.local.name})');

    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      AppStrings.notificationReminderChannelName,
      channelDescription: AppStrings.notificationReminderChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    // 権限があれば時刻ちょうど、無ければ inexact で登録する。
    // 権限が無いまま exact を指定すると例外になるため、必ず事前に確認する。
    final canExact = await canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        _reminderId,
        AppStrings.notificationReminderTitle,
        AppStrings.notificationReminderMessage,
        scheduled,
        details,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint(
          '[NotificationService] zonedSchedule ($scheduleMode) succeeded for id=$_reminderId at $scheduled');
    } catch (e) {
      debugPrint('[NotificationService] zonedSchedule FAILED: $e');
    }

    // pending取得時のクラッシュを防ぐ安全なガード（エラーを修正）
    try {
      final pending = await _plugin.pendingNotificationRequests();
      final pendingLog = pending.map((p) => '${p.id}:${p.title}').toList();
      debugPrint('[NotificationService] pending requests: $pendingLog');
    } catch (e) {
      debugPrint('[NotificationService] Failed to fetch pending requests: $e');
    }
  }

  // ── 作業開始促進：スケジュール解除 ───────────────────
  static Future<void> cancelReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(_reminderId);
  }

  // ── 復帰促進：スケジュール登録 ────────────────────────
  static Future<void> scheduleComebackIfNeeded({
    required DateTime lastPracticeDate,
    required int thresholdDays,
  }) async {
    if (kIsWeb) return;

    await cancelComeback();

    final last = DateTime(
        lastPracticeDate.year, lastPracticeDate.month, lastPracticeDate.day);
    final triggerDate = last.add(Duration(days: thresholdDays));

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      triggerDate.year,
      triggerDate.month,
      triggerDate.day,
      12, // 正午
      0,
    );
    if (scheduled.isBefore(now)) {
      final tomorrow = now.add(const Duration(days: 1));
      scheduled = tz.TZDateTime(
          tz.local, tomorrow.year, tomorrow.month, tomorrow.day, 12, 0);
    }

    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      AppStrings.notificationReminderChannelName,
      channelDescription: AppStrings.notificationReminderChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _plugin.zonedSchedule(
        _comebackId,
        AppStrings.notificationComebackTitle,
        AppStrings.notificationComebackMessage,
        scheduled,
        details,
        // 省電力・アプリ凍結環境でも動作し、ストア審査も安全なモードを指定
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
          '[NotificationService] comeback zonedSchedule (inexact) succeeded at $scheduled');
    } catch (e) {
      debugPrint('[NotificationService] comeback zonedSchedule FAILED: $e');
    }
  }

  // ── 復帰促進：スケジュール解除 ────────────────────────
  static Future<void> cancelComeback() async {
    if (kIsWeb) return;
    await _plugin.cancel(_comebackId);
  }

  // ── Web：アプリ内バナー ────────────────────────────────
  static void _showWebBanner({
    required IconData icon,
    required String title,
    required String message,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$title\n$message',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: AppColors.themeDark,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

// ── ネイティブ：即時プッシュ通知 ──────────────────────
  static Future _showNativeNow({
    required int id,
    required String channelId,
    required String channelName,
    required String channelDesc,
    required String title,
    required String message,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
    await _plugin.show(id, title, message, details);
  }
}
