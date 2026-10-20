import 'package:flutter/material.dart';
import '../../features/drawing/domain/drawing_model.dart';
import '../../features/drawing/domain/drawing_settings.dart';
import '../../features/drawing/ui/drawing_initial_screen.dart';
import '../../features/drawing/ui/drawing_main_screen.dart';
import '../../features/drawing/ui/drawing_settings_screen.dart';
import '../../features/drawing/ui/model_list_screen.dart';
import '../../features/growth/domain/growth_record.dart';
import '../../features/growth/ui/growth_full_image_screen.dart';
import '../../features/growth/ui/growth_main_screen.dart';
import '../../features/growth/ui/upload_complete_screen.dart';
import '../../features/growth/ui/upload_screen.dart';
import '../../features/habit/ui/habit_main_screen.dart';
import '../../features/habit/ui/habit_settings_screen.dart';
import '../../features/habit/ui/habit_timer_screen.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/maintenance/ui/maintenance_screen.dart';
import '../../features/onboarding/ui/onboarding_gate_widget.dart';
import '../../features/topic_generator/ui/topic_history_screen.dart';
import '../../features/topic_generator/ui/topic_main_screen.dart';
import '../../shared/patterns/full_image_screen.dart';
import '../config/onboarding_config.dart';

// ══════════════════════════════════════════════════════════
// ルート定義
//
// 画面遷移は Navigator.push で行い、遷移先（Route）の生成をここに集約する。
//
// 各機能の画面クラスをここでのみ import し、
// 画面間の依存を一本化する。
// DrawingSettingsScreen → DrawingMainScreen のような
// feature 内での遷移もここを経由することで、
// 画面間の直接 import を防ぐ。
// ══════════════════════════════════════════════════════════
abstract class AppRouter {
  /// ホーム画面（アプリ起動時のルート）
  ///
  /// 初回起動時のみ、先にオンボーディング（案内）を表示する。
  static Widget get home => const OnboardingGateWidget(
        topic: OnboardingTopic.home,
        child: HomeScreen(),
      );

  /// X秒ドローイング準備画面へのルート
  ///
  /// 初めて開くときのみ、先にオンボーディング（案内）を表示する。
  static Route<void> drawing() => MaterialPageRoute(
        builder: (_) => const OnboardingGateWidget(
          topic: OnboardingTopic.drawing,
          child: DrawingInitialScreen(),
        ),
      );

  /// X秒ドローイング メイン画面へのルート
  ///
  /// [DrawingInitialScreen] および [DrawingSettingsScreen] から呼び出す。
  /// [settings] に確定済みの設定値を渡すこと。
  static Route<void> drawingMain(DrawingSettings settings) => MaterialPageRoute(
        builder: (_) => DrawingMainScreen(settings: settings),
      );

  /// モデル一覧画面へのルート
  ///
  /// [DrawingInitialScreen] から呼び出す。
  static Route<void> drawingModelList() => MaterialPageRoute(
        builder: (_) => const ModelListScreen(),
      );

  /// X秒ドローイング 設定画面へのルート
  ///
  /// [DrawingInitialScreen] から呼び出す。
  static Route<void> drawingSettings() => MaterialPageRoute(
        builder: (_) => const DrawingSettingsScreen(),
      );

  /// 拡大表示画面へのルート
  ///
  /// [ModelListScreen] から呼び出す。[initialAsset] に最初に表示するモデル、
  /// [allAssets] にペア検索用の全モデル一覧を渡すこと。
  static Route<void> drawingFullImage({
    required DrawingModel initialAsset,
    required List<DrawingModel> allAssets,
  }) =>
      MaterialPageRoute(
        builder: (_) => FullImageScreen(
          initialAsset: initialAsset,
          allAssets: allAssets,
        ),
      );

  /// 習慣化サポート メイン画面へのルート
  ///
  /// 初めて開くときのみ、先にオンボーディング（案内）を表示する。
  static Route<void> habit() => MaterialPageRoute(
        builder: (_) => const OnboardingGateWidget(
          topic: OnboardingTopic.habit,
          child: HabitMainScreen(),
        ),
      );

  /// メンテナンス画面へのルート
  ///
  /// [HomeScreen] から呼び出す。AppConfig.featureMaintenance が true の
  /// 間のみ、ホーム画面にこの画面へのボタンが表示される。
  static Route<void> maintenance() => MaterialPageRoute(
        builder: (_) => const MaintenanceScreen(),
      );

  /// メリハリタイマー画面へのルート
  ///
  /// [initialMinutes] / [initialBreakMinutes] を指定した場合、その値で
  /// タイマーを初期化する（習慣化サポート設定画面の「保存して開始」から使用）。
  /// 省略時は保存済み設定（HabitSettingsRepository）から読み込まれる。
  static Route<void> habitTimer({
    int? initialMinutes,
    int? initialBreakMinutes,
  }) =>
      MaterialPageRoute(
        builder: (_) => HabitTimerScreen(
          initialMinutes: initialMinutes,
          initialBreakMinutes: initialBreakMinutes,
        ),
      );

  /// 習慣化サポート設定画面へのルート
  static Route<void> habitSettings() => MaterialPageRoute(
        builder: (_) => const HabitSettingsScreen(),
      );

  /// 成長記録 メイン画面へのルート
  ///
  /// 初めて開くときのみ、先にオンボーディング（案内）を表示する。
  static Route<void> growth() => MaterialPageRoute(
        builder: (_) => const OnboardingGateWidget(
          topic: OnboardingTopic.growth,
          child: GrowthMainScreen(),
        ),
      );

  /// 成長記録 アップロード画面へのルート
  ///
  /// [GrowthMainScreen] から呼び出す。
  static Route<void> growthUpload() => MaterialPageRoute(
        builder: (_) => const UploadScreen(),
      );

  /// 成長記録 アップロード完了画面へのルート
  ///
  /// [UploadScreen] から呼び出す。[isMaxCountReached] が true の場合、
  /// 保持上限枚数にちょうど到達した旨の特別メッセージを表示する。
  /// [isStreakMilestoneReached] が true の場合、連続アップロード日数が
  /// マイルストーンに到達した旨の特別メッセージを表示する
  /// （両方trueの場合は両方のメッセージを続けて表示する）。
  /// [showFlowerFadeIn]／[showColorFadeIn]／[showMessageFadeIn]／
  /// [showPdfButtonFadeIn] は、花丸・色変え・特別メッセージ・PDFボタンを
  /// それぞれフェードインで表示するかどうか（[GrowthNotifier.confirmUpload]
  /// の戻り値をそのまま渡す）。
  static Route<void> growthUploadComplete({
    bool isMaxCountReached = false,
    bool isStreakMilestoneReached = false,
    bool showFlowerFadeIn = false,
    bool showColorFadeIn = false,
    bool showMessageFadeIn = false,
    bool showPdfButtonFadeIn = false,
  }) =>
      MaterialPageRoute(
        builder: (_) => UploadCompleteScreen(
          isMaxCountReached: isMaxCountReached,
          isStreakMilestoneReached: isStreakMilestoneReached,
          showFlowerFadeIn: showFlowerFadeIn,
          showColorFadeIn: showColorFadeIn,
          showMessageFadeIn: showMessageFadeIn,
          showPdfButtonFadeIn: showPdfButtonFadeIn,
        ),
      );

  /// 成長記録 拡大表示画面へのルート
  ///
  /// [GrowthMainScreen] のサムネタップから呼び出す。[allRecords] に
  /// 前へ/次へボタンでの移動対象となる一覧（表示中の並び順）を渡すこと。
  static Route<void> growthFullImage({
    required GrowthRecord initialRecord,
    required List<GrowthRecord> allRecords,
  }) =>
      MaterialPageRoute(
        builder: (_) => GrowthFullImageScreen(
          initialRecord: initialRecord,
          allRecords: allRecords,
        ),
      );

  /// お題ジェネレーター メイン画面へのルート
  ///
  /// 初めて開くときのみ、先にオンボーディング（案内）を表示する。
  static Route<void> topic() => MaterialPageRoute(
        builder: (_) => const OnboardingGateWidget(
          topic: OnboardingTopic.topic,
          child: TopicMainScreen(),
        ),
      );

  /// お題履歴画面へのルート
  ///
  /// [TopicMainScreen] から呼び出す。選択したお題を Navigator.pop の
  /// 戻り値（String）として返す。未選択のまま戻るボタンで戻った場合は
  /// null が返る。
  static Route<String?> topicHistory() => MaterialPageRoute(
        builder: (_) => const TopicHistoryScreen(),
      );

  // ── 将来実装予定 ─────────────────────────────────────────
  // static Route<void> proLesson() => MaterialPageRoute(builder: (_) => const ProLessonSelectScreen());
}
