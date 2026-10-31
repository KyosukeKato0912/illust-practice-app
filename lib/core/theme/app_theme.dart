import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

// ══════════════════════════════════════════════════════════
// アプリ全体の ThemeData 一元定義
//
// app.dart（MaterialApp）からのみ参照する。
// ══════════════════════════════════════════════════════════
abstract class AppTheme {
  AppTheme._();

  static final ThemeData light = ThemeData(
    // スイッチ・スライダー・日付ピッカー等の標準部品の色も、アプリのテーマカラーに合わせる
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.theme),
    useMaterial3: true,
  );
}
