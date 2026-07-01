// =============================================================================
// ExamVault - Banner Ad Widget
// Shows an AdMob banner ad for FREE (non-premium) users. Premium users see
// nothing — the widget returns a SizedBox.shrink(). This is used on the home
// screen and can be dropped into any screen.
// CRASH-SAFETY: NEVER creates a BannerAd until AdMobService.isInitialized
// is true. Creating an ad before MobileAds.initialize() completes can crash
// the app natively (below Dart's error handlers). Also wraps _loadAd in
// try/catch so a native ad-load exception is contained.
// RE-ENABLED (v1.19): The earlier "v1.14 DEBUGGING: disabled" code path was
// meant to be temporary. It is now re-enabled with full crash-safety: ads
// load only after init, on a post-frame callback, and any failure is silently
// swallowed (widget just stays hidden — never crashes the app).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../services/admob_service.dart';

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
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    // Load the ad after the first frame so the widget is fully mounted and
    // the AdMob SDK has had a chance to initialize. We also re-check
    // AdMobService.isInitialized right before creating the BannerAd.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) _loadAd();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      _bannerAd?.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _loadAd() {
    // Don't attempt to load if AdMob SDK isn't initialized yet.
    if (!AdMobService.isInitialized) {
      // Retry once after a short delay — give init time to finish.
      Future.delayed(const Duration(seconds: 2), () {
        if (!_disposed && !_isLoaded && !_loadFailed) _loadAd();
      });
      return;
    }

    // Skip if this user is premium — ads are for free users only.
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated && auth.user?.isPremium == true) {
      return;
    }

    try {
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
            try {
              ad.dispose();
            } catch (_) {}
            if (!_disposed) {
              setState(() {
                _isLoaded = false;
                _loadFailed = true;
              });
            }
            print('BannerAd failed to load (non-fatal): ${error.code} ${error.message}');
          },
        ),
      )..load();
    } catch (e) {
      // Native ad creation can throw if the SDK state is bad. Contain it.
      print('BannerAd creation/load failed (non-fatal): $e');
      if (!_disposed) {
        setState(() => _loadFailed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Premium users never see ads.
    final auth = Provider.of<AuthProvider>(context);
    if (auth.isAuthenticated && auth.user?.isPremium == true) {
      return const SizedBox.shrink();
    }

    // If ad failed to load or isn't loaded yet, render nothing rather than
    // a blank box — keeps the UI clean.
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
