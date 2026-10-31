import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════
// アプリ全体のカラー定数
//
// 全機能で共通利用するカラーを定義する。
// 機能固有のカラーは各 feature 内で定義する。
// ══════════════════════════════════════════════════════════
abstract class AppColors {
  // アプリ全体のテーマカラー（AppBar・アクセント・ボタン等に共通適用）
  // 薄緑系（lightGreen）。白文字を載せる背景色としても使うため、
  // 白文字とのコントラスト比（約3.2:1）を保てる濃さにしている。
  // これより薄くすると、ボタン・AppBar上の白文字が読みにくくなる。
  static const Color theme       = Color(0xFF689F38); // lightGreen.shade700
  static const Color themeLight  = Color(0xFFF1F8E9); // lightGreen.shade50
  static const Color themeBorder = Color(0xFFAED581); // lightGreen.shade300
  static const Color themeDark   = Color(0xFF33691E); // lightGreen.shade900

  // 未実装機能のグレー（ホーム画面の非活性ボタン）
  static const Color disabled = Color(0xFFBDBDBD); // grey.shade400
  static const Color disabledText = Color(0xFF9E9E9E); // grey.shade500

  // 各画面で共通して使うグレー系の色
  static const Color disabledBackground = Color(0xFFE0E0E0); // grey.shade300（非活性ボタンの背景）
  static const Color border = Color(0xFFE0E0E0); // grey.shade300（枠線・区切り線）
  static const Color subText = Color(0xFF9E9E9E); // grey.shade500（補助テキスト・アイコン）

  // X秒ドローイング 情報パネルのノート風デザイン
  static const Color noteBackground = Color(0xFFFFFDE7); // クリーム（黄みがかった白）
  static const Color noteRuleLine = Color(0xFFBBDEFB); // 薄青の横罫線
  static const Color noteMargin = Color(0xFFEF9A9A); // 赤のマージン縦線

  // ホーム画面 各機能ボタンカラー
  static const Color proArtistLesson = Colors.indigo;

  // 習慣化サポート：継続カレンダー 連続記録の強調色
  // 1〜20日目：薄い黄色 / 21日目以降：濃い黄色
  static const Color habitStreakLight = Color(0xFFFFF59D); // yellow.shade200
  static const Color habitStreakDark  = Color(0xFFFBC02D); // yellow.shade700

  // 成長記録：継続カレンダー 連続記録の強調色
  // 習慣化サポートの継続カレンダーと同じ配色ルール（1〜20日目：薄い黄色 /
  // 21日目以降：濃い黄色）を踏襲する。
  static const Color growthStreakLight = Color(0xFFFFF59D); // yellow.shade200
  static const Color growthStreakDark  = Color(0xFFFBC02D); // yellow.shade700
}
