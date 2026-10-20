import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

// ══════════════════════════════════════════════════════════
// バナー広告ウィジェット
//
// ・Android / iOS : google_mobile_ads による実広告（またはテスト広告）
// ・Web           : AdSense 未取得のためダミー広告枠を表示
//
// ■ 広告ユニット ID
//   リリース時は _adUnitIdAndroid / _adUnitIdIos を
//   AdMob コンソールのプロダクション用 ID に差し替える。
//   現在はテスト用 ID を使用。
// ══════════════════════════════════════════════════════════
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // ── 広告ユニット ID（テスト用）────────────────────────
  static const String _adUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _adUnitIdIos     = 'ca-app-pub-3940256099942544/2934735716';

  static String get _adUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) return _adUnitIdIos;
    return _adUnitIdAndroid;
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Web：ダミー広告枠
    if (kIsWeb) return const _DummyBannerAd();

    // ネイティブ：ロード前は非表示
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ダミー広告枠（Web 確認用）
// ══════════════════════════════════════════════════════════
class _DummyBannerAd extends StatelessWidget {
  const _DummyBannerAd();

  static const double _width  = 320;
  static const double _height = 50;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ad_units_outlined,
              size: 16, color: AppColors.subText),
          const SizedBox(width: 6),
          Text(
            AppStrings.bannerAdLabel,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.subText,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
