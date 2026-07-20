// =============================================================================
// ExamVault - Reusable EmptyState Widget
// =============================================================================
// A consistent, bilingual, animated empty-state presentation widget used
// across all screens that show "no data" states (no tests, no subjects, no
// bookmarks, no purchases, etc.).
//
// Features:
//   - Illustrated icon circle with configurable color (defaults to brand emerald)
//   - Bilingual title + description via L10nText (l10nTitleKey / l10nDescKey)
//     OR plain strings (titleText / descText) for dynamic content
//   - Optional retry button (OutlinedButton with refresh icon)
//   - flutter_animate staggered entrance (icon → title → desc → button)
//   - Dark-mode aware colors
//   - Design tokens (AppTheme.space*, radiusFull, AppFonts.style)
//
// Usage:
//   EmptyState(
//     icon: Icons.inbox,
//     l10nTitleKey: 'test_noTests',
//     l10nDescKey: 'test_noTestsDesc',
//     onRetry: () => setState(() => _reloadKey++),
//   )
//
//   // With dynamic text:
//   EmptyState(
//     icon: Icons.search_off,
//     titleText: 'No results for "$query"',
//     l10nDescKey: 'search_desc',
//   )
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';
import '../l10n/app_localizations.dart';

class EmptyState extends StatelessWidget {
  /// The icon to display in the illustrated circle.
  final IconData icon;

  /// L10n key for the title (bilingual). Takes priority over [titleText].
  final String? l10nTitleKey;

  /// Plain text title (use when the title is dynamic). Ignored if
  /// [l10nTitleKey] is set.
  final String? titleText;

  /// L10n key for the description (bilingual). Takes priority over [descText].
  final String? l10nDescKey;

  /// Plain text description (use when the text is dynamic). Ignored if
  /// [l10nDescKey] is set.
  final String? descText;

  /// Color for the icon and the circle tint. Defaults to brand emerald.
  final Color? iconColor;

  /// L10n key for the retry button label. Defaults to 'retry'.
  final String? retryL10nKey;

  /// If non-null, a retry button is shown with this callback.
  final VoidCallback? onRetry;

  /// Icon size inside the circle. Defaults to 44.
  final double iconSize;

  /// Circle diameter. Defaults to 96.
  final double circleSize;

  const EmptyState({
    super.key,
    required this.icon,
    this.l10nTitleKey,
    this.titleText,
    this.l10nDescKey,
    this.descText,
    this.iconColor,
    this.retryL10nKey,
    this.onRetry,
    this.iconSize = 44,
    this.circleSize = 96,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1917);
    final descColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final effectiveIconColor = iconColor ?? AppTheme.primaryColor;
    final circleColor = effectiveIconColor.withOpacity(0.1);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Illustrated icon circle ----
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: effectiveIconColor,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.1),

            const SizedBox(height: AppTheme.spaceXl),

            // ---- Title ----
            if (l10nTitleKey != null)
              L10nText(
                l10nTitleKey!,
                style: AppFonts.style(
                  size: 16,
                  weight: FontWeight.w700,
                  color: titleColor,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 120.ms, duration: 400.ms)
            else if (titleText != null)
              Text(
                titleText!,
                style: AppFonts.style(
                  size: 16,
                  weight: FontWeight.w700,
                  color: titleColor,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 120.ms, duration: 400.ms),

            // ---- Description ----
            if (l10nDescKey != null)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceSm),
                child: L10nText(
                  l10nDescKey!,
                  style: AppFonts.style(
                    size: 13,
                    height: 1.5,
                    color: descColor,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
              )
            else if (descText != null)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceSm),
                child: Text(
                  descText!,
                  style: AppFonts.style(
                    size: 13,
                    height: 1.5,
                    color: descColor,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
              ),

            // ---- Retry button ----
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spaceXl),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: L10nText(
                  retryL10nKey ?? 'retry',
                  style: AppFonts.style(
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: effectiveIconColor,
                  side: BorderSide(color: effectiveIconColor),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ).animate().fadeIn(delay: 320.ms, duration: 400.ms),
            ],
          ],
        ),
      ),
    );
  }
}
