import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_strings.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/habit/state/habit_practice_provider.dart';

// ══════════════════════════════════════════════════════════
// アプリルートウィジェット
//
// MaterialApp の設定・テーマ注入・初期ルートを定義する。
// エントリポイント（main.dart）からのみ呼び出す。
//
// ⚠ 暫定実装：現フェーズは Navigator.push を使用。
//   go_router 導入時は MaterialApp.router + GoRouter に移行する。
//   ルート定義は app_router.dart に集約済み。
// ══════════════════════════════════════════════════════════
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 復帰促進通知：継続カレンダーの最終記録日の変化を監視して
    // スケジュールを更新する（アプリ起動中は常駐）。
    ref.watch(habitComebackSyncProvider);

    return MaterialApp(
      title: AppStrings.appTitle,
      // Web での SnackBar 表示のために NotificationService に渡すキー
      navigatorKey: NotificationService.navigatorKey,
      theme: AppTheme.light,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale('ja'),
        Locale('en'),
      ],
      home: AppRouter.home,
    );
  }
}
