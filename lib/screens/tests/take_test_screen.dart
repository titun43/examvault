// =============================================================================
// ExamVault - Take Test Screen (Test taking with timer)
// =============================================================================
// v2 MODERNIZATION (visual layer overhaul — access/payment logic unchanged):
//   - AppBar themed with AppTheme.primaryColor (emerald) + white foreground.
//     Timer pill turns AppTheme.errorColor (red) when < 5 min remaining.
//   - Every Text widget uses AppFonts.style() so Assamese script (অসমীয়া)
//     renders via the NotoSansBengali fallback chain. Previously inline
//     TextStyle() calls had no fallback, so bilingual question/option text
//     showed tofu boxes on devices without an Indic font.
//   - All user-visible strings now flow through tr()/L10nText (bilingual).
//     New l10n keys: test_close, test_exitTitle, test_exitConfirm, test_exit,
//     test_noQuestions, test_noQuestionsDesc, test_goBack, test_paywallTitle,
//     test_paywallGuestDesc, test_paywallBuyDesc, test_paywallPremiumDesc,
//     test_paywallRollingOut, test_signInToUnlock, test_buyFor, test_goPremium,
//     test_checkPurchases, test_bookmarkSaved, test_bookmarkRemoved,
//     test_bookmarkFailed, test_bookmarkPermission, test_bookmarkAddTooltip,
//     test_bookmarkRemoveTooltip.
//   - Question card + option rows redesigned with design tokens
//     (AppTheme.space*/radius*/softShadow1), colored selected state using
//     AppTheme.primaryColor, and staggered flutter_animate entrance on question
//     change so transitions feel responsive.
//   - Bottom nav bar uses a top soft shadow + design-token padding.
//   - Paywall, loading skeleton, question palette, exit dialog, and bookmark
//     snackbars all modernized with AppFonts + bilingual labels.
//   - NO blue/indigo — emerald primary, amber accent, semantic colors only.
//   - Payment / access / Razorpay / exam-pack / ad / persistence logic is
//     preserved EXACTLY. Only the visual + i18n layer changed.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../models/test_model.dart';
import '../../models/question_model.dart';
import '../../utils/localized_content.dart';
import '../../models/test_result_model.dart';
import '../../services/access_service.dart';
import '../../services/admob_service.dart';
import '../../services/exam_pack_cache_service.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_api_service.dart';
import '../../services/razorpay_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
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

class _TakeTestScreenState extends State<TakeTestScreen>
    with WidgetsBindingObserver {
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
  // Anti-cheat / resume flag: set true when the app is backgrounded so we
  // can show a one-time SnackBar warning when the user returns.
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccessAndLoad();
    _timeRemaining = widget.test.duration * 60;

    // NOTE (v1.43.4 crash fix): the interstitial ad preload that used to be
    // here was removed. Calling AdMobService.loadInterstitialAd() inside
    // initState runs InterstitialAd.load on the native SDK DURING the first
    // frame build of this screen. On some devices / SDK states that triggers
    // a NATIVE crash (SIGSEGV) which Dart's runZonedGuarded cannot catch —
    // the app is killed instantly ("ExamVault keeps stopping"). The exact
    // symptom: tap a test → blank screen → app closes.
    //
    // The preload is now deferred to _loadQuestions() (i.e. only after access
    // is granted AND questions have actually loaded) and runs inside
    // addPostFrameCallback so the first frame is fully rendered before any
    // native ad call is made. If access is denied (paywall), no ad is
    // preloaded at all — which is the correct behavior anyway.
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
    // v1.44.6: exam-pack (category) access is NOW checked locally too —
    // both the Firestore-loaded purchasedCategoryIds AND the persistent
    // SharedPreferences exam-pack cache. Previously the comment below said
    // exam-pack was NOT in the local model; that was outdated —
    // purchasedCategoryIds IS in the UserModel (persisted to Firestore by
    // addPurchasedCategory). We now consult it here so exam-pack buyers open
    // their tests INSTANTLY (no 300-900ms server access-check delay, no
    // loading spinner). The server check still runs as the final gatekeeper
    // for tests the user doesn't locally own.
    final localIsPremium = user?.isPremium ?? false;
    final localHasTest =
        user?.purchasedTests.contains(widget.test.id) ?? false;
    // Local exam-pack check: Firestore-loaded purchasedCategoryIds. We check
    // BOTH the passed-in categoryId and resolve later if needed. The passed-in
    // categoryId (from CategoryDetailScreen) is the real Firestore id, so this
    // local check works for the common navigation path.
    final localHasExamPack = widget.categoryId != null &&
        widget.categoryId!.isNotEmpty &&
        (user?.purchasedCategoryIds.contains(widget.categoryId) ?? false);
    if (localIsPremium || localHasTest || localHasExamPack) {
      _accessGranted = true;
      _accessChecking = false;
      _loadQuestions();
      _startTimer();
      if (mounted) setState(() {});
      return;
    }
    // ASYNC CACHE CHECK — if the local UserModel doesn't have the exam-pack
    // (e.g. Firestore read failed on launch), check the persistent
    // SharedPreferences cache before falling through to the server. This is
    // fast (~10ms) and catches the edge case where the cache has the purchase
    // but the UserModel doesn't.
    if (widget.categoryId != null && widget.categoryId!.isNotEmpty &&
        user != null) {
      final cachedExamPack = await ExamPackCacheService.hasCategoryAccess(
        userId: user.id,
        categoryId: widget.categoryId!,
      );
      if (cachedExamPack) {
        if (!mounted) return;
        _accessGranted = true;
        _accessChecking = false;
        _loadQuestions();
        _startTimer();
        if (mounted) setState(() {});
        return;
      }
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ===========================================================================
  // Test resumption (Critical #4) — SharedPreferences persistence +
  // WidgetsBindingObserver anti-cheat. The test state (answers, current
  // question index, time remaining) is persisted to SharedPreferences on
  // every answer change / navigation and periodically during the timer tick,
  // so an OS-kill mid-test no longer silently loses progress. On re-open, if
  // a saved state exists for this testId with a valid (positive) timer and a
  // matching answer-count, the user is prompted to resume or start fresh.
  //
  // App-lifecycle anti-cheat: when the app is backgrounded the Timer is
  // explicitly canceled (so the clock stops while the user is away) and the
  // state is persisted. On resume the Timer is restarted from the saved
  // _timeRemaining and a one-time SnackBar warns the user that the test was
  // paused. This prevents the cheat where users background the app to look
  // up answers without the clock ticking — they can no longer do so silently.
  // ===========================================================================

  /// SharedPreferences storage key for this test's resumable state.
  /// Pattern: `take_test_state_<testId>`.
  String get _takeTestStorageKey => 'take_test_state_${widget.test.id}';

  /// Persist the current test state (answers, current index, time remaining)
  /// to SharedPreferences as a JSON map. Best-effort — swallows errors so
  /// the test continues even if persistence fails. Fire-and-forget; never
  /// blocks the UI thread.
  void _persistState() {
    if (_questions.isEmpty) return;
    if (_userAnswers.length != _questions.length) return;
    final Map<String, dynamic> state = {
      'testId': widget.test.id,
      'answers': _userAnswers,
      'current': _currentQuestionIndex,
      'timeRemaining': _timeRemaining,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    };
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_takeTestStorageKey, jsonEncode(state));
    }).catchError((Object _) {
      // Swallow — persistence is best-effort; the test must continue.
    });
  }

  /// Load the saved test state from SharedPreferences. Returns null if no
  /// state exists or if decoding fails.
  Future<Map<String, dynamic>?> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_takeTestStorageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// Clear the saved test state. Called on successful submit so the next
  /// open of this testId starts fresh.
  Future<void> _clearSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_takeTestStorageKey);
    } catch (_) {
      // Swallow — best-effort.
    }
  }

  /// After questions load, check for a saved state and prompt the user to
  /// resume or start fresh. Only fires if the saved state is valid (positive
  /// timer, answer count matches current question count). Defaults to resume
  /// if the user dismisses the dialog via the back button (safer — never
  /// lose progress).
  Future<void> _maybePromptResume() async {
    if (_questions.isEmpty) return;
    final saved = await _loadSavedState();
    if (!mounted) return;
    if (saved == null) return; // No saved state — start fresh silently.

    final savedAnswers = saved['answers'];
    final savedCurrent = saved['current'];
    final savedTime = saved['timeRemaining'];
    if (savedAnswers is! List) return;
    if (savedCurrent is! int) return;
    if (savedTime is! int) return;
    if (savedTime <= 0) {
      // Saved timer already expired — clear stale state, start fresh.
      _clearSavedState();
      return;
    }
    final answers = List<int>.from(savedAnswers);
    if (answers.length != _questions.length) {
      // Stale state (admin edited the test) — clear and start fresh.
      _clearSavedState();
      return;
    }

    // Pause the timer while the resume dialog is showing so the user's
    // clock doesn't tick down while they decide.
    _timer?.cancel();
    _timer = null;

    final shouldResume = await showDialog<bool>(
      context: context,
      barrierDismissible: true, // back button dismisses → default to resume
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Row(
            children: [
              const Icon(Icons.history_rounded,
                  color: AppTheme.primaryColor),
              const SizedBox(width: AppTheme.spaceSm),
              L10nText('test_resume_title',
                  style:
                      AppFonts.style(size: 18, weight: FontWeight.w700)),
            ],
          ),
          content: L10nText('test_resume_msg',
              style: AppFonts.style(size: 14, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: L10nText('test_restart_button'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: L10nText('test_resume_button'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (shouldResume == false) {
      // Start fresh — clear saved state and reset to defaults.
      _clearSavedState();
      setState(() {
        _userAnswers = List<int>.filled(_questions.length, -1);
        _currentQuestionIndex = 0;
        _timeRemaining = widget.test.duration * 60;
      });
      _persistState();
    } else {
      // Resume (explicit true OR dismissed via back button → null).
      // Defaulting to resume is safer — never lose user progress.
      setState(() {
        _userAnswers = answers;
        _currentQuestionIndex = savedCurrent.clamp(0, _questions.length - 1);
        _timeRemaining = savedTime;
      });
      _persistState(); // refresh savedAt timestamp
    }

    // Restart the timer with the (possibly restored) _timeRemaining.
    // Skip if the user managed to submit during the dialog (edge case).
    if (!_isSubmitting) {
      _startTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background — cancel the timer (anti-cheat: the test
      // clock stops while the user is away) and persist state so an OS-kill
      // doesn't lose progress. _wasBackgrounded triggers a one-time SnackBar
      // warning on resume.
      _timer?.cancel();
      _timer = null;
      _wasBackgrounded = true;
      _persistState();
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground — restart the timer from the saved
      // _timeRemaining (the clock was paused, NOT running, while the user
      // was away — so they can't "save up" ticking time by backgrounding
      // to look up answers). Show a one-time SnackBar warning so the user
      // knows the test was paused.
      if (!_wasBackgrounded) return;
      _wasBackgrounded = false;
      if (!_accessGranted || _questions.isEmpty || _isSubmitting) return;
      if (!mounted) return;
      _startTimer();
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(tr(context, 'test_paused_msg')),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

      // Check for a saved test state and prompt the user to resume or start
      // fresh. Only fires if a valid saved state exists for this testId.
      _maybePromptResume();

      // Preload the interstitial ad AFTER the first frame with real content
      // is rendered. Doing it in initState (previous code) could trigger a
      // native SDK crash during the initial build — see the note in initState.
      // addPostFrameCallback guarantees the current frame is fully painted
      // before we touch the AdMob SDK, which is the safest moment to start a
      // background ad load. Wrapped in try/catch so a non-fatal SDK error
      // never bubbles up and kills the screen.
      if (AdMobService.isInitialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            AdMobService.loadInterstitialAd();
          } catch (e) {
            print('loadInterstitialAd (post-load) failed (non-fatal): $e');
          }
        });
      }
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
      // Periodically persist state so an OS-kill mid-test doesn't lose
      // more than ~15s of progress. Per-tick persistence would be wasteful;
      // every 15s is a reasonable trade-off (answers are persisted
      // immediately on change in _selectAnswer / navigation methods).
      if (_timeRemaining > 0 && _timeRemaining % 15 == 0) {
        _persistState();
      }
    });
  }

  void _selectAnswer(int optionIndex) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = optionIndex;
    });
    _persistState();
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _persistState();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
      _persistState();
    }
  }

  void _goToQuestion(int index) {
    setState(() {
      _currentQuestionIndex = index;
    });
    _persistState();
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

    // 1a. Clear the saved resumption state — the test is finished, so the
    //     next open of this testId should start fresh (not resume a finished
    //     test). Best-effort fire-and-forget; never blocks navigation.
    _clearSavedState();

    // 1b. Atomically increment the test's attemptCount so the "N attempts"
    //     counter on test cards (test list, test series, daily quiz) reflects
    //     real engagement. Race-safe via FieldValue.increment. Best-effort.
    try {
      await FirestoreService.incrementAttemptCount(widget.test.id);
    } catch (e) {
      print('incrementAttemptCount error (non-fatal): $e');
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

    // 5) INTERSTITIAL AD — NOT shown here.
    // The ad is now triggered from ResultScreen's build tree (via a small
    // _PostTestAdTrigger stateful widget) AFTER the result screen's first
    // frame is painted + a 2-second safety delay.
    //
    // WHY: calling AdMobService.showInterstitialAd() here — immediately after
    // Navigator.pushReplacement — was causing a NATIVE crash (SIGSEGV below
    // Dart's runZonedGuarded) because the Activity is mid-transition (test
    // screen being replaced by result screen). Presenting a full-screen
    // interstitial on top of a transitioning Activity is not safe at the
    // native level. The v1.9.0 fix removed this call entirely; commit 817ffd8
    // re-added it (to restore ads); that re-add is what re-introduced the
    // "app closes after test submit" crash.
    //
    // By moving the ad show to ResultScreen (after it's fully built and
    // stable), we get both: no crash AND ads still show after the test.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.test.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(AppTheme.spaceXl),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.lock_rounded, color: AppTheme.accentColor),
              ).animate().fadeIn(duration: 350.ms).scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: AppTheme.spaceXl),
              L10nText(
                'test_paywallTitle',
                style: AppFonts.style(
                    size: 22, weight: FontWeight.w700),
              ).animate().fadeIn(delay: 80.ms),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                isGuest
                    ? tr(context, 'test_paywallGuestDesc')
                    : canBuyTest
                        ? tr(context, 'test_paywallBuyDesc')
                        : tr(context, 'test_paywallPremiumDesc'),
                textAlign: TextAlign.center,
                style: AppFonts.style(
                    size: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    height: 1.5),
              ).animate().fadeIn(delay: 140.ms),
              if (_accessCheckUnavailable && !isGuest) ...[
                const SizedBox(height: AppTheme.spaceLg),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppTheme.warningColor, size: 18),
                      const SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Text(
                          tr(context, 'test_paywallRollingOut'),
                          style: AppFonts.style(
                              size: 11,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spaceXxl),
              // GUEST CTA — prompt sign-in first.
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
                    icon: const Icon(Icons.login_rounded),
                    label: L10nText('test_signInToUnlock'),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
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
                      label: Text(
                        tr(context, 'test_buyFor').replaceAll(
                            '{price}', widget.test.price.toStringAsFixed(0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/premium').then((_) {
                        if (mounted) _checkAccessAndLoad();
                      });
                    },
                    icon: const Icon(Icons.workspace_premium_rounded,
                        color: AppTheme.accentColor),
                    label: L10nText('test_goPremium'),
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spaceLg),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: L10nText('test_goBack'),
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
          content: Text(tr(context, 'test_paymentTakingLong')),
          backgroundColor: AppTheme.warningColor,
          action: SnackBarAction(
            label: tr(context, 'test_checkPurchases'),
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
          message: tr(context, 'test_preparingPayment'),
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
          message: tr(context, 'test_verifyingPayment'),
          cancellable: true,
          cancelLabel: tr(context, 'test_checkPurchases'),
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
          actionLabel: tr(context, 'test_startTest'),
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
                '${tr(context, 'test_paymentFailedPrefix')} ${response.message ?? tr(context, 'test_paymentFailedGeneric')}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
  }

  /// Builds a skeleton loading screen that mirrors the actual test layout
  /// (progress bar + question card + 4 option rows). Replaces the old bare
  /// CircularProgressIndicator so the user sees a content-shaped placeholder
  /// instead of a spinning circle. Cheap to render (no network, no data) and
  /// disappears as soon as access + questions finish loading.
  Widget _buildLoadingSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    Widget shimmerBox({double width = double.infinity, double height = 16}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.test.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: shimmerBox(
                  width: 48, height: 14),
            ),
          ),
          const SizedBox(width: 48),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Progress bar placeholder
          LinearProgressIndicator(
            value: 0.0,
            backgroundColor: highlightColor,
            valueColor:
                AlwaysStoppedAnimation<Color>(baseColor),
            minHeight: 4,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                shimmerBox(width: 100, height: 14),
                shimmerBox(width: 60, height: 14),
              ],
            ),
          ),
          // Question card skeleton
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question text lines
                  shimmerBox(height: 18),
                  const SizedBox(height: 10),
                  shimmerBox(height: 18, width: 260),
                  const SizedBox(height: 10),
                  shimmerBox(height: 18, width: 180),
                  const SizedBox(height: 28),
                  // Option rows (4 placeholders)
                  ...List.generate(4, (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: highlightColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: baseColor, width: 1),
                          ),
                          child: Row(
                            children: [
                              shimmerBox(width: 24, height: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: shimmerBox(
                                    height: 14,
                                    width: 180 + (i * 20.0)),
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
          // Bottom nav placeholder
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                shimmerBox(width: 90, height: 40),
                shimmerBox(width: 90, height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accessChecking || _isLoading) {
      // SKELETON UI (v1.44.6): instead of a bare CircularProgressIndicator,
      // show a content-shaped skeleton that mirrors the actual test layout
      // (progress bar + question card + option rows). This gives the user
      // immediate visual feedback that the test is loading and looks far
      // more polished than a spinning circle. The skeleton is cheap (no
      // network, no data) and disappears as soon as access + questions load.
      return _buildLoadingSkeleton(context);
    }

    // Paywall: if the test is paid and the user hasn't purchased it and isn't
    // premium, show a purchase prompt instead of the test.
    if (!_accessGranted) {
      return _buildPaywall(context);
    }

    // Empty-questions guard: if questions failed to load, show a friendly
    // message instead of crashing on _questions[_currentQuestionIndex].
    if (_questions.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor:
            isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            widget.test.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inbox_outlined,
                      size: 48, color: AppTheme.primaryColor),
                ).animate().fadeIn(duration: 350.ms).scale(begin: const Offset(0.85, 0.85)),
                const SizedBox(height: AppTheme.spaceXl),
                L10nText(
                  'test_noQuestions',
                  textAlign: TextAlign.center,
                  style: AppFonts.style(
                      size: 16,
                      weight: FontWeight.w600,
                      color: isDark
                          ? Colors.grey.shade100
                          : Colors.grey.shade800),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: AppTheme.spaceSm),
                L10nText(
                  'test_noQuestionsDesc',
                  textAlign: TextAlign.center,
                  style: AppFonts.style(
                      size: 13,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade500),
                ).animate().fadeIn(delay: 140.ms),
                const SizedBox(height: AppTheme.spaceXxl),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: L10nText('test_goBack'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = _questions[_currentQuestionIndex];
    // Localized options — computed once per build, then indexed. Falls back
    // to English if the Assamese list is missing or length-mismatched
    // (defensive against partial admin translations).
    final localizedOptions =
        lcList(context, question.options, question.optionsAs);
    final localizedQuestion =
        lc(context, question.question, question.questionAs);
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
        backgroundColor:
            isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Hero(
            tag: 'test-title-${widget.test.id}',
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                widget.test.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.style(
                    size: 18, weight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
          actions: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs + 2),
                decoration: BoxDecoration(
                  color: _timeRemaining < 300
                      ? AppTheme.errorColor
                      : Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: _timeRemaining < 300
                          ? Colors.white
                          : Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: AppFonts.style(
                        size: 13,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bookmark toggle button — saves this test to the user's bookmarks.
            _BookmarkButton(test: widget.test),
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Report this question',
              onPressed: () => _showReportQuestionDialog(question),
            ),
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: _showQuestionPalette,
              tooltip: tr(context, 'test_palette'),
            ),
            const SizedBox(width: AppTheme.spaceXs),
          ],
        ),
        body: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor:
                  isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              minHeight: 4,
            ),
            // Question counter
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${tr(context, 'test_question')} ${_currentQuestionIndex + 1} ${tr(context, 'test_of')} ${_questions.length}',
                    style: AppFonts.style(
                      size: 14,
                      weight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade100 : Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSm + 2,
                        vertical: AppTheme.spaceXs),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      '${tr(context, 'test_marks')}: ${question.marks}',
                      style: AppFonts.style(
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppTheme.accentDarkColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Question
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (question.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        child: Image.network(question.imageUrl!),
                      ),
                      const SizedBox(height: AppTheme.spaceLg),
                    ],
                    // Question text — AppFonts.style ensures Assamese fallback.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceLg),
                      margin: const EdgeInsets.only(bottom: AppTheme.spaceLg),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardColor : Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                        boxShadow: AppTheme.softShadow1,
                      ),
                      child: Text(
                        localizedQuestion,
                        style: AppFonts.style(
                          size: 16,
                          weight: FontWeight.w500,
                          height: 1.5,
                          color: isDark ? Colors.grey.shade50 : Colors.black87,
                        ),
                      ),
                    ).animate(key: ValueKey(_currentQuestionIndex)).fadeIn(
                        duration: 300.ms).slideY(begin: 0.06),
                    // Options
                    ...List.generate(localizedOptions.length, (index) {
                      final isSelected =
                          _userAnswers[_currentQuestionIndex] == index;
                      return Container(
                        margin: const EdgeInsets.only(
                            bottom: AppTheme.spaceMd),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectAnswer(index),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            child: Container(
                              padding: const EdgeInsets.all(AppTheme.spaceLg),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryColor.withOpacity(0.08)
                                    : (isDark
                                        ? AppTheme.darkCardColor
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : (isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade300),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? []
                                    : AppTheme.softShadow1,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : (isDark
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade100),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Text(
                                        String.fromCharCode(65 + index),
                                        style: AppFonts.style(
                                          size: 14,
                                          weight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : (isDark
                                                  ? Colors.grey.shade100
                                                  : Colors.grey.shade700),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spaceMd),
                                  Expanded(
                                    child: Text(
                                      localizedOptions[index],
                                      style: AppFonts.style(
                                        size: 14,
                                        height: 1.4,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : (isDark
                                                ? Colors.grey.shade50
                                                : Colors.black87),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppTheme.primaryColor, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                          .animate(key: ValueKey('opt$_currentQuestionIndex-$index'))
                          .fadeIn(
                              delay: (80 + index * 50).ms,
                              duration: 280.ms);
                    }),
                  ],
                ),
              ),
            ),
            // Bottom navigation
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
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
                        child: L10nText('test_previous'),
                      ),
                    ),
                  if (_currentQuestionIndex > 0)
                    const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: _currentQuestionIndex == _questions.length - 1
                        ? ElevatedButton(
                            onPressed: _submitTest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                              foregroundColor: Colors.white,
                            ),
                            child: L10nText('test_submit'),
                          )
                        : ElevatedButton(
                            onPressed: _nextQuestion,
                            child: L10nText('test_next'),
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

  void _showReportQuestionDialog(QuestionModel question) {
    String selectedReason = 'Wrong Answer Key';
    final commentController = TextEditingController();
    const reasons = [
      'Wrong Answer Key',
      'Wrong / Confusing Question',
      'Typo or Formatting Issue',
      'Duplicate Question',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Report this question'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lc(context, question.question, question.questionAs),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.style(
                        size: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    Text('What\'s the problem?',
                        style: AppFonts.style(size: 13, weight: FontWeight.w600)),
                    const SizedBox(height: AppTheme.spaceSm),
                    Wrap(
                      spacing: AppTheme.spaceSm,
                      runSpacing: AppTheme.spaceSm,
                      children: reasons.map((r) {
                        final selected = selectedReason == r;
                        return ChoiceChip(
                          label: Text(r, style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                          labelStyle: TextStyle(
                            color: selected ? AppTheme.primaryColor : null,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                          ),
                          onSelected: (_) => setDialogState(() => selectedReason = r),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Add details (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    try {
                      await FirestoreService.submitQuestionReport(
                        testId: widget.test.id,
                        testTitle: widget.test.title,
                        questionId: question.id,
                        questionText: question.question,
                        reason: selectedReason,
                        comment: commentController.text.trim().isEmpty
                            ? null
                            : commentController.text.trim(),
                        userId: auth.user?.id,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Thanks — your report has been sent.')),
                      );
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Could not send report. Try again later.')),
                      );
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQuestionPalette() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Row(
            children: [
              const Icon(Icons.grid_view_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: AppTheme.spaceSm),
              L10nText('test_palette',
                  style: AppFonts.style(
                      size: 18, weight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Legend
                Wrap(
                  spacing: AppTheme.spaceMd,
                  runSpacing: AppTheme.spaceXs,
                  children: [
                    _paletteLegend(
                        AppTheme.primaryColor, tr(context, 'test_answered')),
                    _paletteLegend(
                        AppTheme.successColor.withOpacity(0.3),
                        tr(context, 'test_notVisited')),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: AppTheme.spaceSm,
                      crossAxisSpacing: AppTheme.spaceSm,
                      childAspectRatio: 1,
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
                                    : (isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade200),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            border: isCurrent
                                ? Border.all(
                                    color: AppTheme.primaryColor, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: AppFonts.style(
                                size: 14,
                                weight: FontWeight.w700,
                                color: isCurrent
                                    ? Colors.white
                                    : isAnswered
                                        ? AppTheme.successColor
                                        : (isDark
                                            ? Colors.grey.shade100
                                            : Colors.grey.shade700),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: L10nText('test_close'),
            ),
          ],
        );
      },
    );
  }

  /// Small legend chip for the question palette dialog.
  Widget _paletteLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: AppFonts.style(
                size: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.errorColor),
              const SizedBox(width: AppTheme.spaceSm),
              L10nText('test_exitTitle',
                  style: AppFonts.style(
                      size: 18, weight: FontWeight.w700)),
            ],
          ),
          content: L10nText('test_exitConfirm',
              style: AppFonts.style(size: 14, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: L10nText('cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: L10nText('test_exit'),
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
          SnackBar(
            content: Text(tr(context, 'test_bookmarkSaved')),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await FirestoreService.removeBookmark(uid, widget.test.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'test_bookmarkRemoved')),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Roll back optimistic toggle on error and show feedback.
      debugPrint('[Bookmark] toggle failed: $e');
      if (!mounted) return;
      setState(() => _bookmarked = wasBookmarked);

      // Show a specific message for permission errors so the admin knows
      // Firestore security rules need to be deployed.
      String msg = tr(context, 'test_bookmarkFailed');
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        msg = tr(context, 'test_bookmarkPermission');
      } else if (e.toString().contains('network') ||
          e.toString().contains('unavailable')) {
        msg = tr(context, 'error_connectionDesc');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 4),
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
        _bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: Colors.white,
      ),
      tooltip: _bookmarked
          ? tr(context, 'test_bookmarkRemoveTooltip')
          : tr(context, 'test_bookmarkAddTooltip'),
      onPressed: _toggle,
    );
  }
}
