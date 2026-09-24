import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/hive_adapters.dart';

// ══════════════════════════════════════════════════════════
// エントリポイント
//
// 初期化処理を行い App を起動する。
// ══════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ① 通知を最優先で安全に起動（エラーが起きてもHiveを巻き込まない）
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('[main] Notification init failed: $e');
  }

  // ② データベースを安全に起動（裏でこれがコケても、通知のループを巻き込まない）
  try {
    await Hive.initFlutter();
    HiveAdapters.registerAll();
  } catch (e) {
    debugPrint('[main] Hive init failed: $e');
  }

  runApp(const ProviderScope(child: App()));
}
