// =============================================================================
// ExamVault - Study Material List Screen
// =============================================================================
// Shows all published study materials of a SPECIFIC TYPE for a subject.
// Examples:
//   - "Previous Papers in History" → list of all previousPaper PDFs
//   - "Study Notes in History" → list of all notes PDFs
//   - "Syllabus in History" → list of syllabus PDFs
//
// Real-time: if the admin adds/removes a material while the user is viewing
// this list, the list updates immediately (Firestore snapshots stream).
//
// Premium gating: materials with isPremium=true show a 👑 lock badge. When a
// non-premium user taps a premium material, a paywall dialog is shown.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/study_material_model.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/offline_aware_stream_builder.dart';
import 'pdf_viewer_screen.dart';
import '../auth/login_screen.dart';
import '../premium/premium_screen.dart';

class MaterialListScreen extends StatefulWidget {
  final SubjectModel subject;
  final StudyMaterialType type;

  const MaterialListScreen({
    super.key,
    required this.subject,
    required this.type,
  });

  @override
  State<MaterialListScreen> createState() => _MaterialListScreenState();
}

class _MaterialListScreenState extends State<MaterialListScreen> {
  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    // Same per-category gradient used by SubjectDetailScreen/TestListScreen —
    // ties this screen visually to the rest of the subject's content instead
    // of the old flat solid-color AppBar.
    final heroGradient = AppTheme.gradientFor(widget.subject.categoryId);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: heroGradient.first,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: heroGradient,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.spaceLg, AppTheme.spaceXl, AppTheme.spaceLg, AppTheme.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.35), width: 1.5),
                              ),
                              child: Center(
                                child: Text(widget.type.emoji,
                                    style: const TextStyle(fontSize: 28)),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _localizedTypeLabel(type),
                                    style: AppFonts.style(
                                      size: 22,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.subject.name,
                                    style: AppFonts.style(
                                      size: 13,
                                      weight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: OfflineAwareStreamBuilder<List<StudyMaterialModel>>(
              stream: FirestoreService.getStudyMaterialsByTypeStream(
                widget.subject.id,
                type,
              ),
              loadingBuilder: (_) => _buildShimmerList(),
              emptyBuilder: (_, retry) => _buildEmptyState(retry),
              offlineBuilder: (_, retry) => _buildOfflineState(retry),
              errorBuilder: (_, error, retry) => _buildErrorState(error, retry),
              dataBuilder: (context, materials, isStale) =>
                  _buildMaterialList(materials, isStale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialList(List<StudyMaterialModel> materials, bool isStale) {
    return Stack(
      children: [
        ListView.builder(
          padding: EdgeInsets.all(AppTheme.spaceLg),
          itemCount: materials.length,
          itemBuilder: (context, index) => _buildMaterialCard(materials[index])
              .animate()
              .fadeIn(
                duration: 300.ms,
                delay: (index * 50).ms,
              )
              .slideY(begin: 0.05),
        ),
        if (isStale) _buildStaleBanner(),
      ],
    );
  }

  Widget _buildMaterialCard(StudyMaterialModel material) {
    final typeColor = _typeColor(material.type);
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow1,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: () => _onMaterialTap(material),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spaceLg),
            child: Row(
              children: [
                // PDF icon / thumbnail — type-tinted background
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf,
                    color: typeColor,
                    size: 28,
                  ),
                ),
                SizedBox(width: AppTheme.spaceMd),
                // Title + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              material.title,
                              style: AppFonts.style(
                                size: 15,
                                weight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (material.isPremium) ...[
                            SizedBox(width: AppTheme.spaceSm),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: AppTheme.accentGradientColors,
                                ),
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSm),
                              ),
                              child: const Icon(
                                Icons.workspace_premium,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: AppTheme.spaceXs),
                      Wrap(
                        spacing: AppTheme.spaceSm,
                        children: [
                          if (material.year != null)
                            _buildMetaChip('${material.year}'),
                          if (material.pages != null)
                            _buildMetaChip(
                              '${material.pages} ${tr(context, 'material_pagesSuffix')}',
                            ),
                          _buildMetaChip(
                            material.isPremium
                                ? tr(context, 'premium')
                                : tr(context, 'free'),
                            isPremium: material.isPremium,
                          ),
                        ],
                      ),
                      if (material.description != null &&
                          material.description!.isNotEmpty) ...[
                        SizedBox(height: AppTheme.spaceSm),
                        Text(
                          material.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.style(
                            size: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: AppTheme.spaceSm),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.4),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(String text, {bool isPremium = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPremium
            ? AppTheme.accentColor.withOpacity(0.15)
            : Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        text,
        style: AppFonts.style(
          size: 11,
          weight: FontWeight.w600,
          color: isPremium
              ? AppTheme.accentColor
              : Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.6),
        ),
      ),
    );
  }

  void _onMaterialTap(StudyMaterialModel material) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // If not logged in → prompt login.
    if (auth.user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // Premium gate: if material is premium and user is not premium → paywall.
    if (material.isPremium && !_isUserPremium(auth.user)) {
      _showPaywallDialog(material);
      return;
    }

    // All checks passed → open the PDF viewer.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          pdfUrl: material.pdfUrl,
          title: material.title,
          materialId: material.id,
        ),
      ),
    );

    // Fire-and-forget analytics: increment download count.
    FirestoreService.incrementMaterialDownloadCount(material.id);
  }

  bool _isUserPremium(UserModel? user) {
    if (user == null) return false;
    // SubscriptionStatus is an enum (free / premium / expired). Admin users
    // (UserRole.admin) also get full premium access.
    return user.subscriptionStatus == SubscriptionStatus.premium ||
        user.role == UserRole.admin;
  }

  void _showPaywallDialog(StudyMaterialModel material) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppTheme.accentGradientColors,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: L10nText(
                'material_premiumTitle',
                style: AppFonts.style(
                  size: 18,
                  weight: FontWeight.w700,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          tr(context, 'material_premiumDesc').replaceAll(
              '{title}', material.title),
          style: AppFonts.style(
            size: 14,
            height: 1.5,
            color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: L10nText(
              'test_maybeLater',
              style: AppFonts.style(
                size: 14,
                weight: FontWeight.w600,
                color: Theme.of(ctx).colorScheme.primary,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            child: L10nText(
              'premium_title',
              style: AppFonts.style(
                size: 14,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(StudyMaterialType type) {
    switch (type) {
      case StudyMaterialType.previousPaper:
        return AppTheme.primaryColor;            // emerald
      case StudyMaterialType.notes:
        return AppTheme.successColor;            // green 600
      case StudyMaterialType.syllabus:
        return AppTheme.warningColor;            // orange 600
    }
  }

  /// Bilingual label for a material type (used in the AppBar + header).
  String _localizedTypeLabel(StudyMaterialType type) {
    switch (type) {
      case StudyMaterialType.previousPaper:
        return tr(context, 'material_typePreviousPaper');
      case StudyMaterialType.notes:
        return tr(context, 'material_typeNotes');
      case StudyMaterialType.syllabus:
        return tr(context, 'material_typeSyllabus');
    }
  }

  /// Bilingual plural label for a material type (used in the empty state).
  String _localizedPluralLabel(StudyMaterialType type) {
    switch (type) {
      case StudyMaterialType.previousPaper:
        return tr(context, 'material_pluralPreviousPaper');
      case StudyMaterialType.notes:
        return tr(context, 'material_pluralNotes');
      case StudyMaterialType.syllabus:
        return tr(context, 'material_pluralSyllabus');
    }
  }

  Widget _buildShimmerList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final highlightColor =
        isDark ? Colors.white24 : Colors.grey.shade100;
    return ListView.builder(
      padding: EdgeInsets.all(AppTheme.spaceLg),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: EdgeInsets.only(bottom: AppTheme.spaceMd),
        padding: EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.softShadow1,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(height: AppTheme.spaceSm),
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(VoidCallback retry) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.type.emoji,
                  style: AppFonts.style(size: 40),
                ),
              ),
            ),
            SizedBox(height: AppTheme.spaceLg),
            Text(
              tr(context, 'material_emptyTitle').replaceAll(
                  '{type}', _localizedPluralLabel(widget.type)),
              style: AppFonts.style(
                size: 16,
                weight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spaceSm),
            L10nText(
              'material_emptyDesc',
              style: AppFonts.style(
                size: 13,
                height: 1.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spaceXl),
            OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: L10nText('refresh',
                  style: AppFonts.style(
                      size: 14, weight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildOfflineState(VoidCallback retry) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off,
                size: 48,
                color: AppTheme.warningColor,
              ),
            ),
            SizedBox(height: AppTheme.spaceLg),
            L10nText(
              'material_offlineTitle',
              style: AppFonts.style(
                size: 16,
                weight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.7),
              ),
            ),
            SizedBox(height: AppTheme.spaceSm),
            L10nText(
              'material_offlineDesc',
              style: AppFonts.style(
                size: 13,
                height: 1.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spaceXl),
            ElevatedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: L10nText('retry',
                  style: AppFonts.style(
                      size: 14, weight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildErrorState(Object error, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.errorColor,
              ),
            ),
            SizedBox(height: AppTheme.spaceLg),
            L10nText(
              'error_generic',
              style: AppFonts.style(
                size: 16,
                weight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.7),
              ),
            ),
            SizedBox(height: AppTheme.spaceXl),
            ElevatedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: L10nText('retry',
                  style: AppFonts.style(
                      size: 14, weight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildStaleBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spaceLg, vertical: 6),
        color: AppTheme.warningColor.withOpacity(0.92),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: L10nText(
                'material_stale',
                style: AppFonts.style(
                  color: Colors.white,
                  size: 12,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
