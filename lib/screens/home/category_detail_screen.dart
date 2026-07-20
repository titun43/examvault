// =============================================================================
// ExamVault - Category Detail Screen (shows subjects in a category)
// =============================================================================
// v1.23+ — server-side access check. Before listing subjects, this screen
// calls AccessService.checkCategoryAccess(category.id). If the backend says
// the user lacks access, a paywall is shown with two options:
//   1. "Unlock this exam (₹X)" → RazorpayService.startExamPackPurchase
//   2. "Go Premium"            → /premium
// If the backend endpoint is not ready yet (404), the screen falls back to
// the legacy local check (auth.isPremium) so the app keeps working.
// =============================================================================

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/category_model.dart';
import '../../models/subject_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/access_service.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_api_service.dart';
import '../../services/razorpay_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/payment_progress_dialog.dart';
import '../../widgets/payment_success_dialog.dart';
import '../auth/login_screen.dart';
import 'subject_detail_screen.dart';

enum _AccessState { loading, allowed, denied, rollingOut }

class CategoryDetailScreen extends StatefulWidget {
  final CategoryModel category;

  const CategoryDetailScreen({super.key, required this.category});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  /// Bumped on pull-to-refresh to force the StreamBuilder to re-subscribe.
  int _reloadKey = 0;

  /// Server-side access state for this category.
  _AccessState _accessState = _AccessState.loading;

  /// LIVE category data — kept fresh by [_categorySub]. The constructor's
  /// [widget.category] is only a snapshot from navigation time. Without this
  /// live subscription, if the admin toggled premium on/off (or changed the
  /// price) while the user was inside this screen, the change wouldn't
  /// reflect until the user navigated away and back. Now the screen
  /// re-checks access the moment [isPremium] or [premiumPrice] changes.
  CategoryModel _liveCategory;
  StreamSubscription<CategoryModel?>? _categorySub;

  _CategoryDetailScreenState()
      : _liveCategory = CategoryModel(
          id: '',
          name: '',
          slug: '',
          createdAt: DateTime(0),
          updatedAt: DateTime(0),
        );

  @override
  void initState() {
    super.initState();
    _liveCategory = widget.category;
    // Subscribe to the category doc so premium/price changes made in the
    // admin panel reflect IMMEDIATELY — no need to navigate away and back.
    _categorySub = FirestoreService.getCategoryStream(_liveCategory.id).listen((cat) {
      if (!mounted || cat == null) return;
      final oldCat = _liveCategory;
      // Only re-check access + rebuild if something that affects the lock
      // or paywall actually changed (isPremium, premiumPrice,
      // premiumDurationMonths, image, name). Avoids needless rebuilds when
      // updatedAt ticks but nothing else moved.
      final premiumChanged =
          oldCat.isPremium != cat.isPremium ||
          oldCat.premiumPrice != cat.premiumPrice ||
          oldCat.premiumDurationMonths != cat.premiumDurationMonths;
      final displayChanged =
          oldCat.name != cat.name ||
          oldCat.icon != cat.icon ||
          oldCat.image != cat.image ||
          oldCat.description != cat.description ||
          oldCat.color != cat.color;
      if (!premiumChanged && !displayChanged) return;
      _liveCategory = cat;
      if (premiumChanged) {
        // Premium status flipped — clear any stale AccessService cache for
        // this category + its tests so the next access check hits the backend
        // with the new premium status. Then re-run the access check so the
        // paywall appears/disappears in real time.
        AccessService.clearCacheForCategory(cat.id);
        _checkAccess();
      } else {
        // Only display fields changed — just rebuild.
        setState(() {});
      }
    });
    _checkAccess();
  }

  @override
  void dispose() {
    _categorySub?.cancel();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    // Fast path: non-premium categories are always open.
    if (!_liveCategory.isPremium) {
      if (!mounted) return;
      setState(() => _accessState = _AccessState.allowed);
      return;
    }
    // GUEST MODE — a guest can't have bought the exam pack, so skip the
    // server check (it would 401) and show the paywall with a Sign-In CTA.
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isGuest) {
      if (!mounted) return;
      setState(() => _accessState = _AccessState.denied);
      return;
    }
    // LOCAL FAST PATH — if the local user model already confirms access
    // (premium subscription or exam-pack purchased), grant immediately without
    // a network round-trip. This eliminates the loading spinner for premium
    // users and exam-pack buyers when re-opening a category they already own.
    if (auth.isPremium || auth.hasCategoryAccess(_liveCategory.id)) {
      if (!mounted) return;
      setState(() => _accessState = _AccessState.allowed);
      return;
    }
    try {
      final decision =
          await AccessService.checkCategoryAccess(_liveCategory.id);
      if (!mounted) return;
      setState(() {
        _accessState =
            decision.allowed ? _AccessState.allowed : _AccessState.denied;
      });
    } on PaymentApiException catch (e) {
      // 404 or other API errors. Fall back to local isPremium check so the
      // app keeps working for users who are already premium locally. If the
      // user is NOT locally premium, show the paywall (denied) instead of a
      // confusing "rolling out" message — the user should be able to buy the
      // exam pack regardless of backend access-check availability.
      if (!mounted) return;
      setState(() {
        _accessState =
            auth.isPremium ? _AccessState.allowed : _AccessState.denied;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accessState =
            auth.isPremium ? _AccessState.allowed : _AccessState.denied;
      });
    }
  }

  /// Kick off an Exam Pack purchase for this category. Shows loading indicators
  /// during the two network steps (createOrder + verifyPayment) so the user
  /// always knows what's happening — fixes "app hang hoye geche" when tapping
  /// "Unlock this exam" with no feedback. On success, shows a prominent success
  /// dialog (not a subtle snackbar), clears the access cache, and re-checks so
  /// the paywall flips to the subjects list.
  ///
  /// BOTH the "Preparing payment..." and "Verifying payment..." dialogs are
  /// cancellable — the user is NEVER trapped. A safety timer force-dismisses
  /// any stuck dialog and points the user to "My Purchases".
  void _startExamPackPurchase() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to make a purchase.')),
      );
      return;
    }
    if (_liveCategory.premiumPrice <= 0) {
      // No exam-pack price configured → fall back to Premium.
      // FIXED: await push so _checkAccess() runs after returning from premium.
      Navigator.pushNamed(context, '/premium').then((_) {
        if (mounted) _checkAccess();
      });
      return;
    }

    final progress = PaymentProgressDialog();
    // `cancelled` only suppresses *error* snackbars after the user explicitly
    // cancelled. It does NOT block onSuccess — a payment that actually
    // succeeded must always be honoured.
    bool cancelled = false;

    void showCheckPurchasesMessage() {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: const Text(
            'Payment is taking longer than expected. Check "My Purchases" to see if it succeeded.',
          ),
          backgroundColor: AppTheme.warningColor,
          action: SnackBarAction(
            label: 'My Purchases',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                Navigator.pushNamed(context, '/my-purchases');
              }
            },
          ),
        ),
      );
    }

    RazorpayService.startExamPackPurchase(
      userId: user.id,
      userName: user.name,
      userEmail: user.email ?? 'user@examvault.com',
      userPhone: user.phoneNumber ?? '9999999999',
      categoryId: _liveCategory.id,
      categoryName: _liveCategory.name,
      amount: _liveCategory.premiumPrice,
      // createOrder is about to start — show "Preparing payment..." with a
      // Cancel button so the user can abort if the network is too slow.
      onPreparing: () {
        if (cancelled) return;
        progress.show(
          context,
          message: 'Preparing payment...',
          cancellable: true,
          onCancel: () => cancelled = true,
          onSafetyTimeout: showCheckPurchasesMessage,
        );
      },
      // Razorpay checkout is about to open — dismiss the "preparing" dialog.
      onCheckoutOpened: () {
        progress.dismiss();
      },
      // Razorpay checkout closed, user paid — /verify is about to run.
      // Show "Verifying payment...". Also cancellable.
      onVerifying: () {
        if (cancelled) return;
        progress.show(
          context,
          message: 'Verifying payment...',
          cancellable: true,
          cancelLabel: 'Check My Purchases',
          safetyTimeout: const Duration(seconds: 60),
          onCancel: () {
            cancelled = true;
            showCheckPurchasesMessage();
          },
          onSafetyTimeout: showCheckPurchasesMessage,
        );
      },
      onSuccess: (response) {
        // ALWAYS process a successful payment — even if the user dismissed
        // the dialog, the payment went through and the exam pack must be
        // unlocked.
        progress.dismiss();
        // Optimistically cache a positive access decision so _checkAccess()
        // returns instantly (within 60s TTL) without hitting the backend —
        // the background /verify might not have completed yet. This matches
        // the pattern used by test_list_screen (markTestPurchased) and
        // premium_screen (markPremiumGranted).
        AccessService.markExamPackPurchased(_liveCategory.id);
        // FIXED: update local user model immediately so home/all-categories
        // screens unlock this category without waiting for loadUserData().
        auth.addPurchasedCategory(_liveCategory.id);
        auth.loadUserData();
        if (!mounted) return;
        // Show a PROMINENT success dialog (not a subtle snackbar). The user
        // taps "Open Exam" to proceed. This fixes "payment er por kichui hoi
        // na" — the user now gets clear, unmissable feedback.
        PaymentSuccessDialog.show(
          context,
          itemName: _liveCategory.name,
          amount: _liveCategory.premiumPrice,
          actionLabel: 'Open Exam',
          paymentId: response.paymentId,
        ).then((_) {
          if (mounted) {
            // Re-check access so the paywall flips to the subjects list.
            _checkAccess();
          }
        });
      },
      onError: (response) {
        progress.dismiss();
        // If the user explicitly cancelled, don't show a scary "Payment
        // failed" message — they already know.
        if (cancelled) return;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Payment failed. Please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_liveCategory.name),
      ),
      body: Column(
        children: [
          // Category image banner (admin-uploaded). Shown only when an image
          // URL is set; otherwise the gradient header below stands on its own.
          if (_liveCategory.image != null &&
              _liveCategory.image!.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 180,
              child: CachedNetworkImage(
                imageUrl: _liveCategory.image!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: (AppTheme.categoryColors[_liveCategory.name] ??
                          AppTheme.primaryColor)
                      .withOpacity(0.3),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: (AppTheme.categoryColors[_liveCategory.name] ??
                          AppTheme.primaryColor)
                      .withOpacity(0.3),
                  child: const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.white, size: 40),
                  ),
                ),
              ),
            ),
          // Header — category-themed 2-stop gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spaceXl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppTheme.gradientFor(_liveCategory.name),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Category icon — wrapped in Hero so it receives the
                    // flying icon from the home screen's category card.
                    Hero(
                      tag: 'category-icon-${_liveCategory.id}',
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.35), width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            _liveCategory.icon ?? '📚',
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceLg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _liveCategory.name,
                            style: AppFonts.style(
                              size: 24,
                              weight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_liveCategory.subjectCount} ${tr(context, 'category_subjectsAvailable')}',
                            style: AppFonts.style(
                              size: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_liveCategory.description != null &&
                    _liveCategory.description!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    _liveCategory.description!,
                    style: AppFonts.style(
                      size: 13,
                      color: Colors.white.withOpacity(0.92),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Body — depends on the server-side access decision.
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_accessState) {
      case _AccessState.loading:
        return _buildLoadingShimmer();
      case _AccessState.allowed:
        return _buildSubjectsList();
      case _AccessState.rollingOut:
        return _buildRollingOutState();
      case _AccessState.denied:
        return _buildPaywall();
    }
  }

  /// Subjects list — same as before, shown when access is granted (or the
  /// category is not premium).
  Widget _buildSubjectsList() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _reloadKey++);
        // Also re-check access on pull-to-refresh.
        await _checkAccess();
        await Future.delayed(const Duration(milliseconds: 400));
      },
      child: StreamBuilder<List<SubjectModel>>(
        key: ValueKey('subjects-${_reloadKey}'),
        stream: FirestoreService.getSubjectsStream(
          categoryId: _liveCategory.id,
          categoryName: _liveCategory.name,
          categorySlug: _liveCategory.slug,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingShimmer();
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final subject = snapshot.data![index];
              return _buildSubjectCard(context, subject);
            },
          );
        },
      ),
    );
  }

  /// Paywall shown when the backend denies access to this premium category.
  /// Two CTAs: "Unlock this exam (₹X)" (Exam Pack purchase) and "Go Premium".
  /// For GUESTS (not signed in), a "Sign In" button is shown instead — guests
  /// can browse but must create an account before they can buy.
  Widget _buildPaywall() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isGuest = auth.isGuest;
    final canBuyExamPack = _liveCategory.premiumPrice > 0;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock,
              size: 56, color: AppTheme.accentColor),
        ),
        const SizedBox(height: 20),
        const Text(
          'Premium Exam Pack',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          isGuest
              ? 'Sign in to unlock "${_liveCategory.name}" and all its tests.'
              : canBuyExamPack
                  ? 'Unlock "${_liveCategory.name}" and all its tests for ₹${_liveCategory.premiumPrice}, or upgrade to Premium for unlimited access.'
                  : 'Subscribe to Premium to unlock "${_liveCategory.name}" and all its tests.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Text(
          '✓ All mock tests in this exam\n✓ Detailed solutions\n✓ Performance analytics',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 24),
        if (isGuest) ...[
          // GUEST CTA — must sign in before purchasing.
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.login),
              label: const Text('Sign In to Unlock'),
            ),
          ),
          const SizedBox(height: 12),
        ] else if (canBuyExamPack) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _startExamPackPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.lock_open),
              label: Text('Unlock this exam (₹${_liveCategory.premiumPrice})'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!isGuest) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/premium').then((_) {
                // FIXED: refresh access when user returns from premium screen.
                if (mounted) _checkAccess();
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentColor,
                side: const BorderSide(color: AppTheme.accentColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.workspace_premium),
              label: const Text('Go Premium'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Maybe later'),
        ),
      ],
    );
  }

  Widget _buildRollingOutState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.hourglass_top, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text(
          'This feature is being rolled out.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Please update the app soon to access premium content in ${_liveCategory.name}.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/premium').then((_) {
            if (mounted) _checkAccess();
          }),
          icon: const Icon(Icons.workspace_premium),
          label: const Text('Explore Premium'),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return EmptyState(
      icon: Icons.cloud_off,
      l10nTitleKey: 'category_errorTitle',
      l10nDescKey: 'category_errorDesc',
      iconColor: AppTheme.errorColor,
      onRetry: () => setState(() => _reloadKey++),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.inbox,
      l10nTitleKey: 'category_noSubjectsTitle',
      l10nDescKey: 'category_noSubjectsDesc',
      onRetry: () => setState(() => _reloadKey++),
    );
  }

  /// Shimmer skeleton list — shown while subjects are loading from
  /// Firestore. Replaces the old centered spinner so the layout doesn't
  /// jump when data arrives.
  Widget _buildLoadingShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.white24 : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, SubjectModel subject) {
    final categoryColor = AppTheme.colorFor(_liveCategory.name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                // Navigate to the SubjectDetailScreen (content hub) instead of
                // going straight to TestListScreen. The hub shows a grid of
                // content-type cards: Tests (always), Previous Papers, Study
                // Notes, Syllabus (each shown only if the admin has added ≥1
                // item of that type — real-time via Firestore stream).
                //
                // We pass the authoritative category.id so the downstream
                // TestListScreen (and TakeTestScreen + /access-check) uses the
                // SAME id that was stored in ExamPackPurchase when the exam
                // pack was bought. Without this, a subject whose Firestore
                // `categoryId` field holds the category NAME/SLUG (allowed by
                // getSubjectsStream's fallback matching) would cause the
                // exam-pack access tier to silently no-match.
                builder: (_) => SubjectDetailScreen(
                  subject: subject,
                  categoryId: _liveCategory.id,
                  categoryName: _liveCategory.name,
                ),
              ),
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardColor : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: AppTheme.softShadow1,
              border: Border.all(
                color: categoryColor.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Row(
                children: [
                  // Icon tile — category-colored.
                  // Wrapped in Hero so it flies to SubjectDetailScreen's
                  // header on tap (tag: 'subject-icon-<id>').
                  Hero(
                    tag: 'subject-icon-${subject.id}',
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Center(
                        child: Text(
                          subject.icon ?? '📚',
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  // Title + description + pills
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: AppFonts.style(
                            size: 16,
                            weight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subject.description != null &&
                            subject.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subject.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.style(size: 12, color: Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: AppTheme.spaceSm),
                        Row(
                          children: [
                            // Test count pill — bilingual
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spaceSm + 2,
                                  vertical: AppTheme.spaceXs),
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusFull),
                              ),
                              child: Text(
                                '${subject.testCount} ${tr(context, 'subject_tests')}',
                                style: AppFonts.style(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                            if (subject.premiumPrice > 0) ...[
                              const SizedBox(width: AppTheme.spaceSm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spaceSm + 2,
                                    vertical: AppTheme.spaceXs),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusFull),
                                ),
                                child: Text(
                                  '₹${subject.premiumPrice}',
                                  style: AppFonts.style(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: AppTheme.accentDarkColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  // Bigger, rounded chevron
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 22,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.04);
  }
}
