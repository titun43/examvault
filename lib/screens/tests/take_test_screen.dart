// =============================================================================
// ExamVault - Take Test Screen (Test taking with timer)
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/test_model.dart';
import '../../models/question_model.dart';
import '../../models/test_result_model.dart';
import '../../services/access_service.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_api_service.dart';
import '../../services/razorpay_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/payment_progress_dialog.dart';
import '../../widgets/payment_success_dialog.dart';
import '../auth/login_screen.dart';
import 'result_screen.dart';

class TakeTestScreen extends StatefulWidget {
  final TestModel test;
  /// Optional: the categoryId this test belongs to. If provided, the
  /// server-side access check can verify exam-pack ownership. If null,
  /// TakeTestScreen will try to resolve it from Firestore via the test's
  /// subjectId (single document read). This is needed because TestModel
  /// does not carry categoryId — only subjectId.
  final String? categoryId;

  const TakeTestScreen({super.key, required this.test, this.categoryId});

  @override
  State<TakeTestScreen> createState() => _TakeTestScreenState();
}

class _TakeTestScreenState extends State<TakeTestScreen> {
  List<QuestionModel> _questions = [];
  List<int> _userAnswers = [];
  int _currentQuestionIndex = 0;
  Timer? _timer;
  int _timeRemaining = 0;
  bool _isLoading = true;
  bool _isSubmitting = false; // guards against double-submission
  bool _accessGranted = false;
  // True while the server-side access check is in flight. Distinguished from
  // _isLoading (which is for question loading) so the paywall doesn't flash
  // before the access decision arrives.
  bool _accessChecking = true;
  // True if the access-check endpoint 404'd (backend not built yet). In that
  // case we fall back to the legacy local check (user.isPremium || hasTest).
  bool _accessCheckUnavailable = false;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
    _timeRemaining = widget.test.duration * 60;
  }

  /// Checks whether the user has access to this test. Uses a FAST LOCAL
  /// CHECK first (premium or purchased in the local UserModel) — if the
  /// local state says the user has access, we grant it immediately and load
  /// questions without any network round-trip. This makes opening a test
  /// after purchasing it INSTANT (the v1.27 fix made the button flip to
  /// "Start Test" after purchase; this fix makes tapping it open the test
  /// without the 350-950ms server access-check delay).
  ///
  /// If the local check says NO access, falls back to the server-side access
  /// check (single source of truth). If the backend grants access, loads
  /// questions; otherwise shows the paywall.
  Future<void> _checkAccessAndLoad() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    // Fast path: free tests never need an access check.
    if (!widget.test.isPaid) {
      _accessGranted = true;
      _accessChecking = false;
      _loadQuestions();
      _startTimer();
      if (mounted) setState(() {});
      return;
    }

    // GUEST MODE — a guest (not signed in) can never open a paid test. Skip
    // the server check (it would 401) and show the paywall with a Sign-In
    // CTA so the user can create an account and then buy / unlock the test.
    if (auth.isGuest) {
      _accessGranted = false;
      _accessChecking = false;
      _isLoading = false;
      if (mounted) setState(() {});
      return;
    }

    // FAST LOCAL CHECK — if the user is premium or has purchased this test
    // (according to the local UserModel, which is updated optimistically
    // after a purchase), grant access immediately. The server-side check is
    // the ultimate gatekeeper, but for a snappy UX we trust the local state
    // first. The 60s cache in AccessService will also return a positive
    // decision instantly if we just checked.
    //
    // NOTE: exam-pack (category) access is NOT in the local UserModel — it
    // lives only in the AccessService cache (written by markExamPackPurchased
    // or by a prior checkCategoryAccess call). We intentionally do NOT
    // short-circuit here for exam-pack — we fall through to the server check
    // below, which will hit the cache (instant) if CategoryDetailScreen or
    // TestListScreen already ran the category access check.
    final localIsPremium = user?.isPremium ?? false;
    final localHasTest =
        user?.purchasedTests.contains(widget.test.id) ?? false;
    if (localIsPremium || localHasTest) {
      _accessGranted = true;
      _accessChecking = false;
      _loadQuestions();
      _startTimer();
      if (mounted) setState(() {});
      return;
    }

    // SERVER CHECK — for tests the user doesn't locally own. This catches
    // entitlements granted on another device or via a backend webhook.
    //
    // CRITICAL: we MUST pass categoryId so the backend can check the exam-pack
    // tier (Tier 2). Without it, a user who purchased an exam pack (category
    // unlock) would be falsely denied access to individual tests in that
    // category — because TestModel only carries subjectId, not categoryId.
    // If the caller didn't pass categoryId, resolve it from Firestore by
    // looking up the subject (single document read).
    String? resolvedCategoryId = widget.categoryId;
    if ((resolvedCategoryId == null || resolvedCategoryId.isEmpty) &&
        widget.test.subjectId.isNotEmpty) {
      final subject =
          await FirestoreService.getSubjectById(widget.test.subjectId);
      // subject.categoryId may be a name or slug instead of the real Firestore
      // document id (the admin may have written it that way). Resolve it to
      // the real id so the backend's exam-pack tier can match correctly.
      resolvedCategoryId =
          await FirestoreService.resolveCategoryId(subject?.categoryId);
    }
    try {
      final decision = await AccessService.checkTestAccess(
        widget.test.id,
        subjectId: widget.test.subjectId.isNotEmpty
            ? widget.test.subjectId
            : null,
        categoryId: resolvedCategoryId,
      );
      if (!mounted) return;
      _accessChecking = false;
      _accessGranted = decision.allowed;
      if (_accessGranted) {
        _loadQuestions();
        _startTimer();
      } else {
        _isLoading = false;
      }
      setState(() {});
    } on PaymentApiException catch (e) {
      if (!mounted) return;
      _accessChecking = false;
      _accessCheckUnavailable = e.statusCode == 404;
      // Fall back to local check.
      _accessGranted = localIsPremium || localHasTest;
      if (_accessGranted) {
        _loadQuestions();
        _startTimer();
      } else {
        _isLoading = false;
      }
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      _accessChecking = false;
      _accessGranted = localIsPremium || localHasTest;
      if (_accessGranted) {
        _loadQuestions();
        _startTimer();
      } else {
        _isLoading = false;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadQuestions() async {
    try {
      final questions = await FirestoreService.getQuestions(widget.test.id);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _userAnswers = List.filled(questions.length, -1);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
        } else {
          _timer?.cancel();
          _submitTest();
        }
      });
    });
  }

  void _selectAnswer(int optionIndex) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = optionIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _goToQuestion(int index) {
    setState(() {
      _currentQuestionIndex = index;
    });
    Navigator.pop(context);
  }

  void _submitTest() {
    // Guard against double-submission (e.g. timer fires while user taps Submit)
    if (_isSubmitting) return;
    _isSubmitting = true;
    _timer?.cancel();

    int correct = 0;
    int wrong = 0;
    int unattempted = 0;
    int obtainedMarks = 0;

    for (int i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] == -1) {
        unattempted++;
      } else if (_userAnswers[i] == _questions[i].correctAnswerIndex) {
        correct++;
        obtainedMarks += _questions[i].marks;
      } else {
        wrong++;
        if (widget.test.negativeMarking) {
          obtainedMarks -= widget.test.negativeMarks.toInt();
        }
      }
    }

    final percentage = _questions.isNotEmpty
        ? (correct / _questions.length) * 100
        : 0.0;
    final accuracy = (correct + wrong) > 0
        ? (correct / (correct + wrong)) * 100
        : 0.0;

    final userId = Provider.of<AuthProvider>(context, listen: false).user?.id ?? '';

    final result = TestResultModel(
      id: '',
      userId: userId,
      testId: widget.test.id,
      testTitle: widget.test.title,
      totalQuestions: _questions.length,
      correctAnswers: correct,
      wrongAnswers: wrong,
      unattempted: unattempted,
      totalMarks: widget.test.totalMarks,
      obtainedMarks: obtainedMarks,
      percentage: percentage,
      isPassed: percentage >= widget.test.passingMarks,
      timeTaken: widget.test.duration * 60 - _timeRemaining,
      totalTime: widget.test.duration * 60,
      userAnswers: _userAnswers,
      correctAnswersList: _questions.map((q) => q.correctAnswerIndex).toList(),
      accuracy: accuracy,
      attemptedAt: DateTime.now(),
    );

    // Save result + update user stats in the background. Wrap each in its own
    // try/catch so a failure in one doesn't block the others, and so a
    // Firestore error never crashes the app after submission (which was
    // the "app auto-closes after taking a test" bug). We navigate to the
    // result screen regardless — the user already finished the test and
    // deserves to see their score.
    //
    // IMPORTANT (v1.9.0 crash fix): The previous version called
    // AdMobService.showInterstitialAd() here. Showing an interstitial ad
    // immediately after test submission was the #1 cause of the post-test
    // native crash — the ad's fullScreenContentCallback was never wired,
    // so a failed/dismissed ad could leave the activity in a broken state
    // and the JVM would tear down the process. We now NEVER show an
    // interstitial on the submit path. Ads may still be shown elsewhere
    // (banners) but never as a blocking modal between test and result.
    _persistAndNavigate(result, userId, correct, _questions.length, percentage);
  }

  Future<void> _persistAndNavigate(
    TestResultModel result,
    String userId,
    int correctAnswers,
    int totalQuestions,
    double percentage,
  ) async {
    // 1) Save the result (best-effort).
    try {
      await FirestoreService.saveResult(result);
    } catch (e) {
      print('saveResult error (non-fatal): $e');
    }

    // 2) Update user aggregate stats (totalTestsAttempted, XP, level, streak,
    //    averageScore). This is what makes the profile test-count update.
    if (userId.isNotEmpty) {
      try {
        await FirestoreService.updateUserStatsAfterTest(
          userId: userId,
          correctAnswers: correctAnswers,
          totalQuestions: totalQuestions,
          percentage: percentage,
        );
      } catch (e) {
        print('updateUserStatsAfterTest error (non-fatal): $e');
      }

      // 3) Refresh the in-memory AuthProvider user so the profile screen
      //    reflects the new counts immediately without requiring a re-login.
      try {
        if (mounted) {
          await Provider.of<AuthProvider>(context, listen: false).loadUserData();
        }
      } catch (e) {
        print('loadUserData after test error (non-fatal): $e');
      }
    }

    // 4) Navigate to result screen. Use pushReplacement so the test screen is
    //    popped off the stack (prevents "back" returning to a finished test).
    //    No interstitial ad in between — see comment in _submitTest().
    if (!mounted) return;
    try {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: result,
            questions: _questions,
            userAnswers: _userAnswers,
          ),
        ),
      );
    } catch (e) {
      print('navigate to result error (non-fatal): $e');
    }
  }

  /// Paywall shown when a user tries to open a paid test they haven't bought
  /// and aren't premium for. Offers two paths:
  ///   1. Buy this test individually (₹{test.price}) — only if the test has a
  ///      per-test price set by admin
  ///   2. Upgrade to Premium for unlimited access
  /// The old "Unlock subject pack ₹99" option was removed because subject-pack
  /// prices are not yet admin-configurable — the hardcoded ₹99 placeholder was
  /// confusing users.
  /// If the access-check endpoint 404'd (backend not built), a "rolling out"
  /// banner is shown above the buttons.
  Widget _buildPaywall(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final isGuest = auth.isGuest;
    final canBuyTest = widget.test.price > 0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.test.title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                'Premium Test',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isGuest
                    ? 'Sign in to unlock this test. Free tests are available without an account.'
                    : canBuyTest
                        ? 'Buy this test or upgrade to Premium for unlimited access.'
                        : 'Upgrade to Premium to attempt this test.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              if (_accessCheckUnavailable && !isGuest) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppTheme.warningColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Live access verification is being rolled out. '
                          'Please update the app soon.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              // GUEST CTA — prompt sign-in first. Once signed in, the user can
              // buy the test or go premium. This matches the product rule:
              // free tests are open to everyone; premium content requires an
              // account.
              if (isGuest) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In to Unlock'),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                if (canBuyTest) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: user == null ? null : _buyTest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: Text('Buy for ₹${widget.test.price}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // FIXED: refresh access when user returns from premium screen.
                      Navigator.pushNamed(context, '/premium').then((_) {
                        if (mounted) _checkAccessAndLoad();
                      });
                    },
                    icon: const Icon(Icons.workspace_premium,
                        color: AppTheme.accentColor),
                    label: const Text('Go Premium'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Buy this single test via the server-side-verified Razorpay flow.
  /// Shows loading indicators during createOrder ("Preparing payment...")
  /// and verifyPayment ("Verifying payment...") so the user always sees
  /// what's happening. On success, writes a positive AccessDecision to the
  /// cache (so the next access check is instant), optimistically marks the
  /// test as purchased locally, and loads the test questions.
  ///
  /// BOTH dialogs are cancellable — the user is NEVER trapped. A 25-second
  /// safety timer force-dismisses any stuck dialog. A successful payment is
  /// ALWAYS processed (onSuccess runs regardless of the `cancelled` flag).
  void _buyTest() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
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

    RazorpayService.startTestPurchase(
      userId: user.id,
      userName: user.name,
      userEmail: user.email ?? 'user@examvault.com',
      userPhone: user.phoneNumber ?? '9999999999',
      testId: widget.test.id,
      testTitle: widget.test.title,
      amount: widget.test.price,
      subjectId: widget.test.subjectId.isNotEmpty ? widget.test.subjectId : null,
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
          // 60s accommodates the verify call (20s) + order-status polling
          // (up to 3 polls × ~13s) which lets the Razorpay webhook fire.
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
        // the dialog, the payment went through and the test must be unlocked.
        progress.dismiss();

        // Write a positive AccessDecision to the cache so the next access
        // check is instant. This is the key fix for the post-payment loading
        // delay — instead of clearing the cache (which forces a network
        // round-trip), we write the positive decision directly.
        AccessService.markTestPurchased(widget.test.id);
        // Optimistically mark the test as purchased locally + persist to
        // Firestore (survives app restart / re-login).
        auth.addPurchasedTest(widget.test.id);
        if (!mounted) return;
        // Show a PROMINENT success dialog before loading the test. The user
        // gets clear feedback that the payment succeeded, then taps "Start
        // Test" to begin. This fixes "payment er por kichui hoi na".
        PaymentSuccessDialog.show(
          context,
          itemName: widget.test.title,
          amount: widget.test.price,
          actionLabel: 'Start Test',
          paymentId: response.paymentId,
        ).then((_) {
          if (!mounted) return;
          // CRITICAL: set _accessChecking = false so the build method's
          // `if (_accessChecking || _isLoading)` guard doesn't keep showing
          // the loading screen forever. After payment success we KNOW access
          // is granted, so we skip directly to loading questions.
          setState(() {
            _accessChecking = false;
            _accessGranted = true;
            _isLoading = true;
          });
          _loadQuestions();
          _startTimer();
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
            content: Text(
                'Payment failed: ${response.message ?? 'Please try again.'}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accessChecking || _isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Paywall: if the test is paid and the user hasn't purchased it and isn't
    // premium, show a purchase prompt instead of the test.
    if (!_accessGranted) {
      return _buildPaywall(context);
    }

    // Empty-questions guard: if questions failed to load, show a friendly
    // message instead of crashing on _questions[_currentQuestionIndex].
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.test.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No questions available for this test yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = _questions[_currentQuestionIndex];
    final minutes = _timeRemaining ~/ 60;
    final seconds = _timeRemaining % 60;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _showExitDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.test.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _timeRemaining < 300 ? Colors.red : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Bookmark toggle button — saves this test to the user's bookmarks.
            _BookmarkButton(test: widget.test),
            IconButton(
              icon: const Icon(Icons.grid_view),
              onPressed: _showQuestionPalette,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            // Question counter
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade100 : Colors.black87,
                    ),
                  ),
                  Text(
                    'Marks: ${question.marks}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            // Question
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (question.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(question.imageUrl!),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      question.question,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: isDark ? Colors.grey.shade50 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Options
                    ...List.generate(question.options.length, (index) {
                      final isSelected = _userAnswers[_currentQuestionIndex] == index;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _selectAnswer(index),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withOpacity(0.1)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : (isDark ? Colors.grey.shade700 : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + index),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? Colors.grey.shade100 : Colors.grey.shade700),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    question.options[index],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : (isDark ? Colors.grey.shade50 : Colors.black87),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            // Bottom navigation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentQuestionIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousQuestion,
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentQuestionIndex > 0)
                    const SizedBox(width: 12),
                  Expanded(
                    child: _currentQuestionIndex == _questions.length - 1
                        ? ElevatedButton(
                            onPressed: _submitTest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                            ),
                            child: const Text('Submit Test'),
                          )
                        : ElevatedButton(
                            onPressed: _nextQuestion,
                            child: const Text('Next'),
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

  void _showQuestionPalette() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Question Palette'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final isAnswered = _userAnswers[index] != -1;
                final isCurrent = index == _currentQuestionIndex;
                return GestureDetector(
                  onTap: () => _goToQuestion(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.primaryColor
                          : isAnswered
                              ? AppTheme.successColor.withOpacity(0.2)
                              : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrent
                          ? Border.all(color: AppTheme.primaryColor, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? Colors.white
                              : isAnswered
                                  ? AppTheme.successColor
                                  : (isDark ? Colors.grey.shade100 : Colors.grey.shade700),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exit Test?'),
          content: const Text('Your progress will be lost. Are you sure?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// _BookmarkButton — stateful bookmark toggle shown in TakeTestScreen's AppBar.
// Reads the initial bookmark state once on mount, then toggles on tap.
// Skips the Firestore call for guests (no uid).
// =============================================================================
class _BookmarkButton extends StatefulWidget {
  final TestModel test;
  const _BookmarkButton({required this.test});

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  bool _bookmarked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
  }

  Future<void> _checkBookmark() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.user?.id;
    if (uid == null || uid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final b = await FirestoreService.isBookmarked(uid, widget.test.id);
    if (!mounted) return;
    setState(() {
      _bookmarked = b;
      _loading = false;
    });
  }

  Future<void> _toggle() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.user?.id;
    if (uid == null || uid.isEmpty) {
      // Guest — prompt login.
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final wasBookmarked = _bookmarked;
    setState(() => _bookmarked = !_bookmarked);
    try {
      if (_bookmarked) {
        await FirestoreService.addBookmark(
          uid,
          widget.test.id,
          widget.test.title,
          subjectId: widget.test.subjectId.isNotEmpty ? widget.test.subjectId : null,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bookmark saved'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await FirestoreService.removeBookmark(uid, widget.test.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bookmark removed'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Roll back optimistic toggle on error and show feedback.
      if (!mounted) return;
      setState(() => _bookmarked = wasBookmarked);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update bookmark. Please try again.'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 48);
    return IconButton(
      icon: Icon(
        _bookmarked ? Icons.bookmark : Icons.bookmark_border,
        color: Colors.white,
      ),
      tooltip: _bookmarked ? 'Remove bookmark' : 'Bookmark this test',
      onPressed: _toggle,
    );
  }
}
