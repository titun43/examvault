// =============================================================================
// ExamVault - Banner Ad Widget
// Shows an AdMob banner ad for FREE (non-premium) users. Premium users see
// nothing — the widget returns a SizedBox.shrink(). This is used on the home
// screen and can be dropped into any screen.
// CRASH-SAFETY (v1.13+): NEVER creates a BannerAd until AdMobService.isInitialized
// is true. Creating an ad before MobileAds.initialize() completes can crash
// the app natively (below Dart's error handlers). Also wraps _loadAd in
// try/catch so a native ad-load exception is contained.
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
    // v1.14 DEBUGGING: AdMob BannerAd.load() is an ASYNC NATIVE call that
    // can crash BELOW Dart's try/catch if the AdMob SDK has an issue (invalid
    // ad unit, Play Services problem, etc.). To isolate whether AdMob is the
    // crash source, we temporarily DISABLE ad loading entirely. The widget
    // renders nothing. Once we confirm the crash is gone, we can re-enable
    // ads with a safer approach (e.g. delayed init, or a dedicated ad screen).
    // _loadAd is NOT called here.
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
    // v1.14 DEBUGGING: AdMob disabled entirely to isolate crash source.
    // Always return nothing. No native ad code runs at all.
    return const SizedBox.shrink();
  }
}
