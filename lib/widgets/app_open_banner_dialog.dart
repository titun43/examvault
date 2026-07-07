// =============================================================================
// ExamVault - App Open Banner Dialog (Full-Screen)
// =============================================================================
// Full-screen promotional banner shown once per app launch, between the
// splash screen and the main navigation. Admin uploads a full-screen image
// and (optionally) a CTA button.
//
// UX:
//   - Tapping the image / CTA button → runActionButton (external URL or
//     in-app navigation), then closes the dialog.
//   - Tapping the ❌ close button (top-right, 48×48 touch target) closes
//     the dialog WITHOUT triggering the action.
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
// result (true = user tapped action, false/null = user dismissed).
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/app_open_banner_model.dart';
import '../services/firestore_service.dart';
import '../utils/in_app_navigator.dart';

class AppOpenBannerDialog extends StatefulWidget {
  final AppOpenBannerModel banner;

  const AppOpenBannerDialog({super.key, required this.banner});

  /// Convenience method: shows the dialog and waits for dismissal.
  /// Returns true if the user tapped the banner/CTA, false otherwise.
  static Future<bool> show(BuildContext context, AppOpenBannerModel banner) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      useRootNavigator: true,
      builder: (_) => AppOpenBannerDialog(banner: banner),
    ).then((v) => v ?? false);
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

  Future<void> _close({bool tapped = false}) async {
    if (_actionTriggered) return;
    _actionTriggered = true;
    await _fadeController.reverse();
    if (!mounted) return;
    Navigator.of(context).pop(tapped);
  }

  Future<void> _onBannerTapped() async {
    final btn = widget.banner.primaryButton;
    if (btn == null || !btn.isSet) {
      // No CTA configured — close the dialog (treat tap as dismiss).
      await _close(tapped: false);
      return;
    }
    // Log click (best-effort, non-blocking).
    FirestoreService.incrementAppOpenBannerClick(widget.banner.id);
    // Close the dialog FIRST so the action opens on a clean nav stack.
    await _close(tapped: true);
    if (!mounted) return;
    // Then run the action (may open URL or push a screen).
    await runActionButton(context, btn);
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
                      if (banner.title != null ||
                          banner.subtitle != null ||
                          hasCta)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                24, 0, 24, 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (banner.title != null)
                                  Text(
                                    banner.title!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                if (banner.subtitle != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    banner.subtitle!,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                if (hasCta) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _onBannerTapped,
                                    child: Text(
                                      banner.primaryButton!.label,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
