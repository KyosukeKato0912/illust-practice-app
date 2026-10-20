import 'package:flutter/material.dart';
import '../../../core/config/onboarding_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

// ══════════════════════════════════════════════════════════
// オンボーディング画面（初回案内）
//
// [topic] に対応するページ一覧（OnboardingConfig.pagesOf）を
// 横スワイプで表示する。右上の「スキップ」、最終ページの「はじめる」の
// どちらでも [onFinished] が呼ばれる。
// 既読の記録や、案内後に何を表示するかは呼び出し側
// （OnboardingGateWidget）が担当し、この画面は表示だけを行う。
// ══════════════════════════════════════════════════════════
class OnboardingScreen extends StatefulWidget {
  final OnboardingTopic topic;

  /// 「スキップ」または最終ページの「はじめる」を押したときに呼ばれる
  final VoidCallback onFinished;

  const OnboardingScreen({
    super.key,
    required this.topic,
    required this.onFinished,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // ── レイアウト定数 ─────────────────────────────────────
  static const double _contentMaxWidth = 480;
  static const Duration _pageAnimation = Duration(milliseconds: 250);

  final PageController _controller = PageController();
  late final List<OnboardingPageDef> _pages =
      OnboardingConfig.pagesOf(widget.topic);
  int _page = 0;

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_isLast) {
      widget.onFinished();
    } else {
      _controller.nextPage(duration: _pageAnimation, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: Column(
              children: [
                // スキップ（最終ページでは非表示。高さは維持してレイアウトを揺らさない）
                Align(
                  alignment: Alignment.centerRight,
                  child: Visibility(
                    visible: !_isLast,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextButton(
                      onPressed: widget.onFinished,
                      child: const Text(AppStrings.onboardingSkip),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _OnboardingPageView(def: _pages[i]),
                  ),
                ),
                _DotsIndicator(count: _pages.length, current: _page),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.theme,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _onNext,
                      child: Text(
                        _isLast
                            ? AppStrings.onboardingStart
                            : AppStrings.onboardingNext,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 1ページ分の表示（アイコン・見出し・本文）
// ══════════════════════════════════════════════════════════
class _OnboardingPageView extends StatelessWidget {
  final OnboardingPageDef def;

  const _OnboardingPageView({required this.def});

  static const double _iconCircleSize = 120;
  static const double _iconSize = 56;

  @override
  Widget build(BuildContext context) {
    // 画面が低い端末・文字サイズ拡大時でもはみ出さないようスクロール可能にする
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: _iconCircleSize,
                  height: _iconCircleSize,
                  decoration: const BoxDecoration(
                    color: AppColors.themeLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(def.icon, size: _iconSize, color: AppColors.theme),
                ),
                const SizedBox(height: 32),
                Text(
                  def.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  def.body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, height: 1.7),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
// ページ位置を示すドット
// ══════════════════════════════════════════════════════════
class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _DotsIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final bool active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.theme : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
