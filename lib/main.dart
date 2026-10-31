import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/constants/app_strings.dart';
import 'core/services/notification_service.dart';
import 'core/services/hive_adapters.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/file_utils.dart';
import 'core/utils/logger.dart';

// ══════════════════════════════════════════════════════════
// エントリポイント
//
// 初期化処理を行い App を起動する。
// ══════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ① 通知を最優先で安全に起動（エラーが起きてもHiveを巻き込まない）
  //    通知は付加機能のため、失敗してもアプリ本体は起動する。
  try {
    await NotificationService.initialize();
  } catch (e) {
    AppLogger.log('[main] Notification init failed: $e');
  }

  // ①' 画像保存先パスの基準ディレクトリを取得する（成長記録の相対パス解決に使う）。
  //    Web等で取得できない場合は、保存値をそのまま使う動作に切り替わるだけなので、
  //    失敗しても起動は続ける。Hive の読み出し（TypeAdapter）より前に行うこと。
  try {
    await AppFileUtils.initialize();
  } catch (e) {
    AppLogger.log('[main] AppFileUtils init skipped: $e');
  }

  // ② データベースを起動する。
  //    成長記録・お題履歴などの永続化の前提となるため、失敗した状態で
  //    通常画面に進むと、以降のBox操作で例外が連鎖する。失敗時は起動せず、
  //    再試行できるエラー画面を表示する。
  if (await _initializeHive()) {
    runApp(const ProviderScope(child: App()));
  } else {
    runApp(const _StartupErrorApp(onRetry: _initializeHive));
  }
}

/// Hiveの初期化とアダプタ登録を行う。成功なら true。
Future<bool> _initializeHive() async {
  try {
    await Hive.initFlutter();
    HiveAdapters.registerAll();
    return true;
  } catch (e, st) {
    AppLogger.log('[main] Hive init failed: $e');
    AppLogger.log('$st');
    return false;
  }
}

// ══════════════════════════════════════════════════════════
// 起動エラー画面
//
// Hive初期化に失敗したときだけ表示する。再試行が成功したら
// 通常のアプリ（App）に切り替える。
// ══════════════════════════════════════════════════════════
class _StartupErrorApp extends StatefulWidget {
  /// 初期化を再実行し、成功なら true を返す。
  final Future<bool> Function() onRetry;

  const _StartupErrorApp({required this.onRetry});

  @override
  State<_StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<_StartupErrorApp> {
  bool _retrying = false;
  bool _retryFailed = false;

  Future<void> _retry() async {
    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    final ok = await widget.onRetry();
    if (!mounted) return;
    if (ok) {
      runApp(const ProviderScope(child: App()));
    } else {
      setState(() {
        _retrying = false;
        _retryFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            // 文字サイズを大きくしても、ボタンまで届くようスクロール可能にする
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    AppStrings.startupErrorTitle,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    AppStrings.startupErrorMessage,
                    textAlign: TextAlign.center,
                  ),
                  if (_retryFailed) ...[
                    const SizedBox(height: 12),
                    const Text(
                      AppStrings.startupErrorRetryFailed,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _retrying ? null : _retry,
                    child: _retrying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(AppStrings.startupErrorRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
