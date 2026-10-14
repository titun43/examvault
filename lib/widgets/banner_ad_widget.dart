// =============================================================================
// ExamVault - Banner Ad Widget
// Shows a banner ad at the bottom of screens.
// Premium users never see this (shouldShowAds check).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!AdMobService.shouldShowAds) return;
    if (!AdMobService.isInitialized) {
      // Retry after 2 seconds if SDK not ready
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _loadAd();
      });
      return;
    }

    _bannerAd = AdMobService.createBannerAd(
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() {
            _isLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        _isLoaded = false;
      },
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdMobService.shouldShowAds) {
      return const SizedBox.shrink();
    }
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox(height: 50);
    }
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
