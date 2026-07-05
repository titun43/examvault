// =============================================================================
// ExamVault - All Categories Screen
// Shows ALL exam categories in a full-screen grid (with pull-to-refresh).
// Reached from the "View All" button next to "Exam Categories" on the home
// screen. Previously that button opened the All Subjects screen, which was
// the wrong destination — users expected to see more categories, not a flat
// subject list.
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/access_service.dart';
import '../../services/firestore_service.dart';
import '../../services/razorpay_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/payment_progress_dialog.dart';
import '../../widgets/payment_success_dialog.dart';
import '../auth/login_screen.dart';
import 'category_detail_screen.dart';

class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  int _reloadKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Exam Categories')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _reloadKey++);
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: StreamBuilder<List<CategoryModel>>(
          key: ValueKey('all-cats-$_reloadKey'),
          stream: FirestoreService.getCategoriesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Couldn\'t load categories.\nPlease check your connection and retry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No categories available yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              );
            }
            final categories = snapshot.data!;
            // Sort client-side by order then name.
            categories.sort((a, b) {
              final o = a.order.compareTo(b.order);
              return o != 0 ? o : a.name.compareTo(b.name);
            });
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.95,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) =>
                  _buildCategoryCard(categories[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    final color =
        AppTheme.categoryColors[category.name] ?? AppTheme.primaryColor;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // FIXED: check exam-pack purchase too, not just premium subscription.
    final categoryLocked = category.isPremium && !auth.hasCategoryAccess(category.id);
    // Show admin-uploaded category image as the card background when present.
    final hasImage =
        category.image != null && category.image!.isNotEmpty;

    // Shared content layer (emoji circle + name + subject count + price tag).
    // Rendered on top of either the image background or the color gradient.
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Center(
            child: Text(
              category.icon ?? '📚',
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          category.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${category.subjectCount} Subjects',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 11,
          ),
        ),
        if (categoryLocked && category.premiumPrice > 0) ...[
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '₹${category.premiumPrice}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );

    // Background layer: full-bleed image + dark overlay (when image present),
    // otherwise the original color gradient. Falls back to the gradient on
    // image load error or while loading so the card never looks empty.
    final BoxDecoration gradientDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, color.withOpacity(0.7)],
      ),
    );
    final Widget background;
    if (hasImage) {
      background = Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: category.image!,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                DecoratedBox(decoration: gradientDecoration),
            errorWidget: (_, __, ___) =>
                DecoratedBox(decoration: gradientDecoration),
          ),
          // Dark gradient overlay so the white text stays legible on top
          // of any image. Stronger at the bottom, lighter near the top.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.65),
                  Colors.black.withOpacity(0.2),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      background = DecoratedBox(decoration: gradientDecoration);
    }

    return GestureDetector(
      onTap: () {
        // Same real-lock behavior as the home screen.
        if (categoryLocked) {
          _showPaywall(category);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryDetailScreen(category: category),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                background,
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
              ],
            ),
          ),
          if (category.isPremium)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: categoryLocked
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryLocked ? Icons.lock : Icons.workspace_premium,
                  size: 14,
                  color:
                      categoryLocked ? AppTheme.accentColor : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPaywall(CategoryModel category) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final isGuest = auth.isGuest;
    final canBuyExamPack = category.premiumPrice > 0;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock,
                    size: 48, color: AppTheme.accentColor),
              ),
              const SizedBox(height: 16),
              const Text('Premium Category',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                isGuest
                    ? 'Sign in to unlock "${category.name}" and all its tests.'
                    : canBuyExamPack
                        ? 'Unlock "${category.name}" and all its tests for ₹${category.premiumPrice}, or upgrade to Premium for unlimited access.'
                        : 'Subscribe to Premium to unlock "${category.name}" and all its tests.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                '✓ All mock tests in this exam\n✓ Detailed Solutions\n✓ Performance Analytics',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          actions: [
            if (isGuest) ...[
              // GUEST CTA — must sign in before purchasing.
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
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
            ] else ...[
              if (canBuyExamPack)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: user == null
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _startExamPackPurchase(category, auth);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.lock_open),
                    label: Text(
                        'Unlock this exam (₹${category.premiumPrice})'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // FIXED: refresh lock state when user returns from premium.
                    Navigator.pushNamed(context, '/premium').then((_) {
                      if (mounted) setState(() {});
                    });
                  },
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
            ],
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Maybe later'),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Starts an Exam Pack purchase from the All Categories paywall. Shows
  /// loading indicators during the two network steps (createOrder + verify)
  /// so the user always knows what's happening — fixes "app hang hoye geche"
  /// when tapping "Unlock this exam" with no feedback. On server-verified
  /// success, clears the access cache + refreshes the user + shows a prominent
  /// success dialog, then opens the category detail screen.
  void _startExamPackPurchase(
    CategoryModel category,
    AuthProvider auth,
  ) {
    final user = auth.user;
    if (user == null) return;

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
      categoryId: category.id,
      categoryName: category.name,
      amount: category.premiumPrice,
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
      onCheckoutOpened: () {
        progress.dismiss();
      },
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
        // Optimistically cache a positive access decision so the
        // CategoryDetailScreen's _checkAccess() returns instantly. The
        // background /verify might not have completed yet.
        AccessService.markExamPackPurchased(category.id);
        auth.loadUserData();
        if (!mounted) return;
        // Show a PROMINENT success dialog (not a subtle snackbar). The user
        // taps "Open Exam" to proceed. This fixes "payment er por kichui hoi
        // na" — the user now gets clear, unmissable feedback.
        PaymentSuccessDialog.show(
          context,
          itemName: category.name,
          amount: category.premiumPrice,
          actionLabel: 'Open Exam',
          paymentId: response.paymentId,
        ).then((shouldOpen) {
          if (!mounted) return;
          // Always open the category so the user can start browsing —
          // regardless of whether they tapped "Open Exam" or "Later", the
          // exam pack is unlocked now.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryDetailScreen(category: category),
            ),
          );
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
            content:
                Text(response.message ?? 'Payment failed. Please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
  }
}
