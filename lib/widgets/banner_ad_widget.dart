// =============================================================================
// ExamVault - Banner Ad Widget
// Shows an AdMob banner ad for FREE (non-premium) users. Premium users see
// nothing — the widget returns a SizedBox.shrink(). This is used on the home
// screen and can be dropped into any screen.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';

class BannerAdWidget extends StatefulWidget {
  /// Optional size; defaults to the standard banner (320x50).
  final AdSize size;

  const BannerAdWidget({super.key, this.size = AdSize.banner});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
    _disposed = true;
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AppConfig.admobTestMode
          ? AppConfig.testBannerAdUnitId
          : AppConfig.bannerAdUnitId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!_disposed) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!_disposed) setState(() => _isLoaded = false);
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    // Hide ads for premium users — they paid for an ad-free experience.
    final auth = Provider.of<AuthProvider>(context);
    if (auth.isPremium) return const SizedBox.shrink();

    if (!_isLoaded || _bannerAd == null) {
      // Reserve space so the layout doesn't jump when the ad loads.
      return SizedBox(
        height: widget.size.height.toDouble(),
        width: widget.size.width.toDouble(),
      );
    }
    return SizedBox(
      height: _bannerAd!.size.height.toDouble(),
      width: _bannerAd!.size.width.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
