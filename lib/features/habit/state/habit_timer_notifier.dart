import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/int_ext.dart';
import '../../../core/services/notification_service.dart';
import '../domain/habit_settings_repository.dart';

// ══════════════════════════════════════════════════════════
// メリハリタイマー 状態
// ══════════════════════════════════════════════════════════
class HabitTimerState {
  final int totalSeconds;       // 作業時間（秒）
  final int breakTotalSeconds;  // 休憩時間（秒）
  final int remainingSeconds;   // 現フェーズの残り秒数
  final int countUpSeconds;     // カウントアップの経過秒数
  final bool isRunning;
  final bool isBreak;           // true = 休憩中、false = 作業中
  final bool justSwitched;      // フェーズ切替直後フラグ

  const HabitTimerState({
    this.totalSeconds = 0,
    this.breakTotalSeconds = 0,
    this.remainingSeconds = 0,
    this.countUpSeconds = 0,
    this.isRunning = false,
    this.isBreak = false,
    this.justSwitched = false,
  });

  bool get isReady => totalSeconds > 0;

  HabitTimerState copyWith({
    int? totalSeconds,
    int? breakTotalSeconds,
    int? remainingSeconds,
    int? countUpSeconds,
    bool? isRunning,
    bool? isBreak,
    bool? justSwitched,
  }) =>
      HabitTimerState(
        totalSeconds: totalSeconds ?? this.totalSeconds,
        breakTotalSeconds: breakTotalSeconds ?? this.breakTotalSeconds,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        countUpSeconds: countUpSeconds ?? this.countUpSeconds,
        isRunning: isRunning ?? this.isRunning,
        isBreak: isBreak ?? this.isBreak,
        justSwitched: justSwitched ?? this.justSwitched,
      );

  // カウントダウン表示（MM:SS）
  String get displayTime {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // カウントアップ表示（HH:MM:SS）
  String get displayCountUp => countUpSeconds.toHHMMSS();
}

// ══════════════════════════════════════════════════════════
// メリハリタイマー StateNotifier
//
// Timer をここで保持することで、画面（HabitTimerScreen）が
// dispose されてもカウントダウンが継続する。
// ProviderScope の生存中（= アプリ起動中）は状態が維持される。
//
// ── フェーズ切替ルール ──
//   作業中タイマーが 0 → 自動で休憩タイマーに切替（タイマー継続）
//   休憩中にリセットボタン → 作業中の開始時間に戻る（停止）
//   作業中にリセットボタン → 作業中の開始時間に戻る（停止）
//
// ⚠ このタイマー自体は記録を永続化しない。
//   継続カレンダーに表示されるデータは、成長記録（GrowthRecord）で
//   画像を登録（ファイル・写真いずれか）したタイミングにのみ作られる。
//   習慣化サポート・成長記録どちらの継続カレンダーも同じ
//   GrowthRecord（growthProvider）を参照する。
// ══════════════════════════════════════════════════════════
class HabitTimerNotifier extends StateNotifier<HabitTimerState> {
  HabitTimerNotifier() : super(const HabitTimerState());

  Timer? _timer;

  // ── 初期化 ────────────────────────────────────────────
  Future<void> init({int? initialMinutes, int? initialBreakMinutes}) async {
    // カウントダウン中は再初期化しない
    if (state.isRunning) return;

    int minutes;
    int breakMinutes;
    if (initialMinutes != null && initialBreakMinutes != null) {
      minutes = initialMinutes;
      breakMinutes = initialBreakMinutes;
    } else {
      final saved = await HabitSettingsRepository.load();
      minutes = saved?.timerMinutes ?? HabitSettingsRepository.defaultTimerMinutes;
      breakMinutes = saved?.breakMinutes ?? HabitSettingsRepository.defaultBreakMinutes;
    }

    final totalSec = minutes * 60;
    final breakTotalSec = breakMinutes * 60;

    // すでに同じ設定で初期化済みなら残り秒数を保持
    if (state.totalSeconds == totalSec &&
        state.breakTotalSeconds == breakTotalSec &&
        !state.isBreak) return;

    state = HabitTimerState(
      totalSeconds: totalSec,
      breakTotalSeconds: breakTotalSec,
      remainingSeconds: totalSec,
    );
  }

  // ── 開始 ─────────────────────────────────────────────
  void start() {
    if (state.isRunning || state.remainingSeconds <= 0) return;
    state = state.copyWith(isRunning: true, justSwitched: false);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.remainingSeconds <= 1) {
        // フェーズ切替
        _onPhaseEnd();
      } else {
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
          // 作業中のみカウントアップを進める
          countUpSeconds: state.isBreak
              ? state.countUpSeconds
              : state.countUpSeconds + 1,
        );
      }
    });
  }

  // ── フェーズ終了処理 ──────────────────────────────────
  void _onPhaseEnd() {
    _timer?.cancel();
    final wasBreak = state.isBreak;

    if (wasBreak) {
      // 休憩 → 作業に切替
      state = state.copyWith(
        remainingSeconds: state.totalSeconds,
        isRunning: false,
        isBreak: false,
        justSwitched: true,
      );
      // 通知：休憩終了 → 作業開始（画面表示中でもバナー通知。作業終了時と同じ方針）
      NotificationService.showBreakFinished();
      // 自動で作業タイマーを再開
      _resumeAfterSwitch();
    } else {
      // 作業 → 休憩に切替
      state = state.copyWith(
        remainingSeconds: state.breakTotalSeconds,
        countUpSeconds: state.countUpSeconds + 1,
        isRunning: false,
        isBreak: true,
        justSwitched: true,
      );
      // 通知：作業終了 → 休憩開始（画面表示中でもバナー通知）
      NotificationService.showWorkFinished();
      // 自動で休憩タイマーを再開
      _resumeAfterSwitch();
    }
  }

  // ── フェーズ切替後に自動再開 ──────────────────────────
  void _resumeAfterSwitch() {
    state = state.copyWith(isRunning: true, justSwitched: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.remainingSeconds <= 1) {
        _onPhaseEnd();
      } else {
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
          countUpSeconds: state.isBreak
              ? state.countUpSeconds
              : state.countUpSeconds + 1,
        );
      }
    });
  }

  // ── 一時停止 ──────────────────────────────────────────
  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  // ── 作業中リセット ────────────────────────────────────
  // 作業中・休憩中どちらで押しても、必ず作業中の開始状態に戻し停止する。
  void resetCountDown() {
    _timer?.cancel();
    state = state.copyWith(
      remainingSeconds: state.totalSeconds,
      isRunning: false,
      isBreak: false,
      justSwitched: false,
    );
  }

  // ── 総作業時間リセット（作業中・総作業時間ともに停止＋リセット）──
  // 確認ダイアログ経由でのみ呼ぶこと。
  void resetAll() {
    _timer?.cancel();
    state = HabitTimerState(
      totalSeconds: state.totalSeconds,
      breakTotalSeconds: state.breakTotalSeconds,
      remainingSeconds: state.totalSeconds,
      countUpSeconds: 0,
    );
  }

  // ── 設定変更時のリセット（新しい分数を反映）──────────────
  // 総作業時間（countUpSeconds）はリセットせず引き継ぐ。
  // リセットされるのはリセットボタン押下とアプリ終了時のみ。
  void resetWithMinutes({required int minutes, required int breakMinutes}) {
    _timer?.cancel();
    final totalSec = minutes * 60;
    final breakTotalSec = breakMinutes * 60;
    state = HabitTimerState(
      totalSeconds: totalSec,
      breakTotalSeconds: breakTotalSec,
      remainingSeconds: totalSec,
      countUpSeconds: state.countUpSeconds, // 積み上げ時間を保持
    );
  }

  // ── justSwitched フラグを消費 ──────────────────────────
  void consumeSwitched() {
    state = state.copyWith(justSwitched: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ── Provider 定義 ─────────────────────────────────────────
final habitTimerProvider =
    StateNotifierProvider<HabitTimerNotifier, HabitTimerState>(
  (ref) => HabitTimerNotifier(),
);
