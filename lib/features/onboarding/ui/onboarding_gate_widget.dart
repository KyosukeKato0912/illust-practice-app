import 'package:flutter/material.dart';
import '../../../core/config/onboarding_config.dart';
import '../state/onboarding_controller.dart';
import 'onboarding_screen.dart';

// ══════════════════════════════════════════════════════════
// オンボーディング ゲート
//
// [topic] の案内を初めて開くときだけ OnboardingScreen を表示し、
// 終了後（またはスキップ後）に [child] を表示する。
// 既読の場合は最初から [child] を表示する。
//
// AppRouter の各ルートで、機能のメイン画面を包む形で使う。
// 既存の画面（child）側には変更を加えない。
//
// ・既読の記録は案内の終了時に行う。案内の途中で戻るボタンなどで
//   離脱した場合は未読のままなので、次回また案内が表示される。
// ・既読の読み書きに失敗しても案内で操作を止めない
//   （読み込み失敗＝既読扱い、書き込み失敗＝次回また案内が出るだけ）。
// ══════════════════════════════════════════════════════════
class OnboardingGateWidget extends StatefulWidget {
  final OnboardingTopic topic;
  final Widget child;

  const OnboardingGateWidget({
    super.key,
    required this.topic,
    required this.child,
  });

  @override
  State<OnboardingGateWidget> createState() => _OnboardingGateWidgetState();
}

class _OnboardingGateWidgetState extends State<OnboardingGateWidget> {
  /// null = 既読かどうかを判定中、true = 案内を表示、false = child を表示
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    bool seen;
    try {
      seen = await OnboardingController.isSeen(widget.topic);
    } catch (_) {
      seen = true;
    }
    if (!mounted) return;
    setState(() => _showOnboarding = !seen);
  }

  Future<void> _onFinished() async {
    // 記録の完了を待たず、先に表示を進める
    setState(() => _showOnboarding = false);
    try {
      await OnboardingController.markSeen(widget.topic);
    } catch (_) {
      // 記録できなくても操作は止めない（次回また案内が表示されるだけ）
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool? show = _showOnboarding;
    if (show == null) {
      // 既読判定中（ごく短時間）。画面のちらつきを避けるため白一色にする。
      return const Scaffold(backgroundColor: Colors.white);
    }
    if (show) {
      return OnboardingScreen(topic: widget.topic, onFinished: _onFinished);
    }
    return widget.child;
  }
}
