// =============================================================================
// ExamVault - App Open Banner Dialog (Full-Screen)
// =============================================================================
// Full-screen promotional banner shown once per app launch, between the
// splash screen and the main navigation. Admin uploads a full-screen image
// and (optionally) a CTA button.
//
// UX:
//   - Tapping the image / CTA button → logs the click, then closes the dialog
//     and returns the tapped ActionButton to the caller (splash screen), which
//     runs the action (external URL or in-app navigation) AFTER navigating to
//     the home screen (see _BannerActionRunner in splash_screen.dart).
//   - Tapping the ❌ close button (top-right, 48×48 touch target) closes
//     the dialog WITHOUT triggering the action (returns null).
//   - Android back button also closes the dialog (no action triggered).
//   - Fade-in (200ms) on show, fade-out (200ms) on dismiss.
//
// Analytics:
//   - Impression counter is incremented server-side as soon as the dialog
//     is shown (best-effort, non-blocking).
//   - Click counter is incremented only when the user taps the banner/CTA.
//
// This widget is a self-contained StatefulWidget shown via showDialog().
// The splash screen decides WHETHER to show it (frequency cap + audience
// targeting), so this widget just renders + reports back via the dialog
// result (the tapped ActionButton, or null if the user dismissed). The
// CALLER runs the returned action — this widget never navigates itself,
// which avoids a race with the splash screen's pushReplacement.
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/action_button.dart';
import '../models/app_open_banner_model.dart';
import '../services/firestore_service.dart';

class AppOpenBannerDialog extends StatefulWidget {
  final AppOpenBannerModel banner;

  const AppOpenBannerDialog({super.key, required this.banner});

  /// Convenience method: shows the dialog and waits for dismissal.
  /// Returns the tapped [ActionButton] if the user tapped the banner/CTA,
  /// or `null` if the user dismissed it (close button / back button).
  ///
  /// The CALLER is responsible for running the returned action — this widget
  /// only reports what was tapped. This avoids a bug where the splash screen's
  /// `pushReplacement` would replace the in-app screen the dialog had just
  /// pushed (see _BannerActionRunner in splash_screen.dart).
  static Future<ActionButton?> show(
      BuildContext context, AppOpenBannerModel banner) {
    return showDialog<ActionButton>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      useRootNavigator: true,
      builder: (_) => AppOpenBannerDialog(banner: banner),
    );
  }

  @override
  State<AppOpenBannerDialog> createState() => _AppOpenBannerDialogState();
}

class _AppOpenBannerDialogState extends State<AppOpenBannerDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  bool _impressionLogged = false;
  bool _actionTriggered = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
    // Best-effort impression logging (fire-and-forget).
    if (!_impressionLogged) {
      _impressionLogged = true;
      FirestoreService.incrementAppOpenBannerImpression(widget.banner.id);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _close({ActionButton? tappedAction}) async {
    if (_actionTriggered) return;
    _actionTriggered = true;
    await _fadeController.reverse();
    if (!mounted) return;
    Navigator.of(context).pop(tappedAction);
  }

  Future<void> _onBannerTapped() async {
    final btn = widget.banner.primaryButton;
    if (btn == null || !btn.isSet) {
      // No CTA configured — close the dialog (treat tap as dismiss).
      await _close(tappedAction: null);
      return;
    }
    // Log click (best-effort, non-blocking).
    FirestoreService.incrementAppOpenBannerClick(widget.banner.id);
    // Close the dialog, returning the tapped action to the caller. The caller
    // (splash screen) runs the action AFTER navigating to home so the in-app
    // screen isn't replaced by pushReplacement.
    await _close(tappedAction: btn);
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.banner;
    final hasCta = banner.primaryButton != null && banner.primaryButton!.isSet;
    return FadeTransition(
      opacity: _fade,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // ---- Full-screen banner image (tap = action) ----
              Positioned.fill(
                child: GestureDetector(
                  onTap: _onBannerTapped,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: banner.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                      // Subtle dark gradient at the bottom for text legibility.
                      if (banner.title != null || banner.subtitle != null)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 220,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Optional overlay title/subtitle/CTA at the bottom.
                      // Wrapped in a translucent "frosted glass" card with an
                      // amber border for legibility over arbitrary banner
                      // images + a colorful, premium look.
                      if (banner.title != null ||
                          banner.subtitle != null ||
                          hasCta)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                20, 0, 20, 32),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                  20, 18, 20, 20),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.35),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  if (banner.title != null)
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                        colors: [
                                          Color(0xFFFFD54F), // amber 200
                                          Color(0xFFFF6F00), // deep orange 900
                                        ],
                                      ).createShader(bounds),
                                      child: Text(
                                        banner.title!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                          letterSpacing: 0.2,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              offset: Offset(1, 1),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  if (banner.subtitle != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      banner.subtitle!,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withOpacity(0.95),
                                        fontSize: 15,
                                        height: 1.35,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            offset: const Offset(1, 1),
                                            blurRadius: 3,
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                  if (hasCta) ...[
                                    const SizedBox(height: 18),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF6F00), // deep orange 900
                                            Color(0xFFFFAB00), // amber accent 400
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.orange
                                                .withOpacity(0.45),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          onTap: _onBannerTapped,
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 16),
                                            alignment: Alignment.center,
                                            child: Text(
                                              banner.primaryButton!.label,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // ---- ❌ Close button (top-right, 48×48 touch target) ----
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _close(tapped: false),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
