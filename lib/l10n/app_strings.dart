// =============================================================================
// ExamVault - Bilingual String Map (English + অসমীয়া Assamese)
// =============================================================================
// Every UI string has an English and an Assamese form. The tr() helper in
// app_localizations.dart picks which form to show based on the user's
// LanguageProvider preference (english / assamese / both).
//
// Convention:
//   - Keys are lowerCamelCase, grouped by screen/feature.
//   - Assamese strings use proper script (অসমীয়া).
//   - Keep strings short; long copy goes in a separate *_desc key.
// =============================================================================

class AppStrings {
  AppStrings._();

  // ==================== GENERIC ====================
  static const Map<String, String> english = {
    // Generic
    'loading': 'Loading...',
    'retry': 'Retry',
    'refresh': 'Refresh',
    'cancel': 'Cancel',
    'save': 'Save',
    'done': 'Done',
    'continue': 'Continue',
    'back': 'Back',
    'search': 'Search',
    'error': 'Something went wrong',
    'empty': 'Nothing here yet',
    'seeAll': 'See All',
    'viewAll': 'View All',
    'new': 'NEW',
    'free': 'FREE',
    'premium': 'Premium',
    'unlock': 'Unlock',
    'startNow': 'Start Now',
    'getStarted': 'Get Started',

    // Bottom Nav
    'nav_home': 'Home',
    'nav_exams': 'Exams',
    'nav_practice': 'Practice',
    'nav_profile': 'Profile',

    // Home Screen
    'home_welcome': 'Welcome back',
    'home_subtitle': 'Let\'s ace your exam today',
    'home_categories': 'Exam Categories',
    'home_popular': 'Popular Subjects',
    'home_upcoming': 'Upcoming Exams',
    'home_currentAffairs': 'Current Affairs',
    'home_announcements': 'Announcements',
    'home_dailyQuiz': 'Daily Quiz',
    'home_streak': 'Day Streak',
    'home_continueLearning': 'Continue Learning',
    'home_exploreExams': 'Explore Exams',
    // Home Screen — Phase 3.1 modernization additions
    'home_guestMsg':
        'Browsing as guest. Sign in to unlock premium tests & save progress.',
    'home_signIn': 'Sign In',
    'home_quickMock': 'Mock Tests',
    'home_quickUpcoming': 'Upcoming',
    'home_quickBookmarks': 'Bookmarks',
    'home_apply': 'Apply',
    'home_important': 'Important',
    'home_updates': 'Updates',
    'home_premiumHeadline': 'Unlock ExamVault Premium',
    'home_premiumCta': 'Upgrade Now',
    'home_premiumSubtitle2':
        'Get unlimited tests, detailed solutions & more',
    'home_noCategories': 'No categories available',
    'home_noSubjects': 'No subjects available yet',
    'home_noUpcoming': 'No upcoming exams scheduled',
    'home_noCurrentAffairs': 'No current affairs available',
    'home_days': 'days',
    'home_daysAgo': 'days ago',

    // Category / Subjects
    'category_subjects': 'Subjects',
    'category_subjectsAvailable': 'Subjects Available',
    'category_testsAvailable': 'Tests Available',
    'category_chooseSubject': 'Choose a subject to start practicing',
    'category_allSubjects': 'All Subjects',
    'subject_tests': 'Tests',
    'subject_description': 'Description',
    'subject_startMock': 'Start a Mock Test',
    'subject_browseContent': 'Browse content for this subject',
    'subject_contentTypes': 'Content',
    'subject_studyMaterial': 'Study Material',
    'subject_previousPapers': 'Previous Papers',
    'subject_studyNotes': 'Study Notes',
    'subject_syllabus': 'Syllabus',
    'subject_items': 'items',
    'subject_item': 'item',
    'subject_recent': 'Recent Activity',
    'subject_exploreMore': 'Explore More',

    // Test List
    'test_all': 'All',
    'test_free': 'Free',
    'test_premium': 'Premium',
    'test_mock': 'Mock',
    'test_previousYear': 'Previous Year',
    'test_startTest': 'Start Test',
    'test_unlockPremium': 'Unlock with Premium',
    'test_buyNow': 'Buy Now',
    'test_duration': 'min',
    'test_marks': 'marks',
    'test_questions': 'Questions',
    'test_attempts': 'attempts',
    'test_negativeMarking': 'Negative marking',
    'test_year': 'Year',
    'test_noTests': 'No tests available',
    'test_noTestsDesc': 'Tests for this subject will appear here soon.',
    'test_checkBackSoon': 'Check back soon!',
    'test_loadingTests': 'Loading tests...',
    'test_noMatchingTests': 'No tests match this filter',
    'test_noMatchingTestsDesc': 'Try a different filter.',
    'test_clearFilter': 'Clear filter',
    'test_unableToLoad': 'Unable to load tests.',
    'test_unableToLoadDesc': 'Please check your connection and retry.',
    'test_unlockSubject': 'Unlock all tests in {subject}',
    'test_unlockSubjectDesc': 'Get access to every test in this subject',
    'test_unlockTest': 'Unlock "{title}"',
    'test_buyOrPremiumDesc':
        'Buy this test or upgrade to Premium. All payments are secure & verified.',
    'test_premiumOnlyDesc':
        'Upgrade to Premium for unlimited access. All payments are secure & verified.',
    'test_buyThisTest': 'Buy this test',
    'test_attemptAnytime': 'attempt anytime',
    'test_unlimitedAccess': 'Unlimited access to everything',
    'test_maybeLater': 'Maybe later',
    'test_paymentTakingLong':
        'Payment is taking longer than expected. Check "My Purchases" to see if it succeeded.',
    'test_preparingPayment': 'Preparing payment...',
    'test_verifyingPayment': 'Verifying payment...',
    'test_paymentFailedPrefix': 'Payment failed:',
    'test_paymentFailedGeneric': 'Please try again.',
    'test_openTest': 'Open Test',
    'test_signInToPurchase': 'Please sign in to make a purchase.',
    'test_subjectPackPrefix': 'Subject Pack: ',
    'test_premiumOnlyHint': 'Subscribe to Premium to attempt this test.',
    'test_paidHint': 'Buy this test or upgrade to Premium.',

    // Take Test
    'test_question': 'Question',
    'test_of': 'of',
    'test_timeLeft': 'Time Left',
    'test_previous': 'Previous',
    'test_next': 'Next',
    'test_markReview': 'Mark for Review',
    'test_submit': 'Submit Test',
    'test_saveNext': 'Save & Next',
    'test_clear': 'Clear',
    'test_palette': 'Question Palette',
    'test_answered': 'Answered',
    'test_notAnswered': 'Not Answered',
    'test_marked': 'Marked',
    'test_notVisited': 'Not Visited',
    // Take Test — v2 modernization additions
    'test_close': 'Close',
    'test_exitTitle': 'Exit Test?',
    'test_exitConfirm': 'Your progress will be lost. Are you sure?',
    'test_exit': 'Exit',
    'test_noQuestions': 'No questions available for this test yet.',
    'test_noQuestionsDesc': 'Questions will appear here once published.',
    'test_goBack': 'Go Back',
    'test_paywallTitle': 'Premium Test',
    'test_paywallGuestDesc':
        'Sign in to unlock this test. Free tests are available without an account.',
    'test_paywallBuyDesc':
        'Buy this test or upgrade to Premium for unlimited access.',
    'test_paywallPremiumDesc': 'Upgrade to Premium to attempt this test.',
    'test_paywallRollingOut':
        'Live access verification is being rolled out. Please update the app soon.',
    'test_signInToUnlock': 'Sign In to Unlock',
    'test_buyFor': 'Buy for ₹{price}',
    'test_goPremium': 'Go Premium',
    'test_checkPurchases': 'Check My Purchases',
    'test_bookmarkSaved': 'Bookmark saved',
    'test_bookmarkRemoved': 'Bookmark removed',
    'test_bookmarkFailed': 'Failed to update bookmark. Please try again.',
    'test_bookmarkPermission':
        'Bookmark error: permission denied. Admin must deploy Firestore rules.',
    'test_bookmarkAddTooltip': 'Bookmark this test',
    'test_bookmarkRemoveTooltip': 'Remove bookmark',
    // Take Test — resumption + lifecycle anti-cheat (Critical #4)
    'test_resume_title': 'Resume Test?',
    'test_resume_msg':
        'You have an unfinished test. Would you like to resume from where you left off?',
    'test_resume_button': 'Resume',
    'test_restart_button': 'Start Fresh',
    'test_paused_msg':
        'Test was paused while you were away. Timer resumed.',

    // Result
    'result_score': 'Your Score',
    'result_correct': 'Correct',
    'result_wrong': 'Wrong',
    'result_skipped': 'Skipped',
    'result_timeTaken': 'Time Taken',
    'result_rank': 'Your Rank',
    'result_retake': 'Retake Test',
    'result_share': 'Share Result',
    'result_review': 'Review Answers',
    'result_excellent': 'Excellent! 🎉',
    'result_good': 'Good job! 👏',
    'result_keepGoing': 'Keep practicing! 💪',
    'result_correctAnswer': 'Correct Answer',
    'result_yourAnswer': 'Your Answer',
    'result_explanation': 'Explanation',
    'result_testResult': 'Test Result',
    'result_answerReview': 'Answer Review',

    // Profile
    'profile_edit': 'Edit Profile',
    'profile_bookmarks': 'Bookmarks',
    'profile_testHistory': 'Test History',
    'profile_settings': 'Settings',
    'profile_help': 'Help & Support',
    'profile_logout': 'Logout',
    'profile_premium': 'Go Premium',
    'profile_myPurchases': 'My Purchases',

    // Premium
    'premium_title': 'Go Premium',
    'premium_subtitle': 'Unlock all tests & features',
    'premium_allTests': 'All Mock Tests',
    'premium_noAds': 'Ad-free experience',
    'premium_detailedSolutions': 'Detailed Solutions',
    'premium_performanceAnalytics': 'Performance Analytics',
    'premium_priority': 'Priority Support',
    'premium_subscribe': 'Subscribe Now',
    'premium_perMonth': '/month',
    'premium_perYear': '/year',

    // Settings
    'settings_language': 'Language',
    'settings_english': 'English',
    'settings_assamese': 'অসমীয়া',
    'settings_both': 'Both',
    'settings_theme': 'Theme',
    'settings_light': 'Light',
    'settings_dark': 'Dark',
    'settings_system': 'System',
    'settings_notifications': 'Notifications',

    // Account / Delete Account (Google Play Data Deletion policy — Jan 2024)
    'settings_account': 'Account',
    'settings_delete_account': 'Delete Account',
    'settings_delete_account_subtitle':
        'Permanently delete your account and data',
    'settings_delete_account_confirm_title': 'Delete Account?',
    'settings_delete_account_confirm_msg':
        'This will permanently delete your account, test history, bookmarks, and purchases. This action cannot be undone.',
    'settings_delete_account_type_to_confirm': 'Type DELETE to confirm',
    'settings_delete_account_final_button': 'Yes, Delete My Account',
    'settings_delete_account_cancel': 'Cancel',
    'settings_delete_account_success':
        'Account deleted. You have been signed out.',
    'settings_delete_account_failed': 'Could not delete account',

    // About / Legal
    'about': 'About',
    'appVersion': 'App Version',
    'privacyPolicy': 'Privacy Policy',
    'termsConditions': 'Terms & Conditions',
    'refundPolicy': 'Refund Policy',

    // Empty / Error states
    'empty_bookmarks': 'No bookmarks yet',
    'empty_bookmarksDesc': 'Bookmark questions to review them later.',
    'empty_history': 'No test history yet',
    'empty_historyDesc': 'Take your first test to see it here.',
    'error_connection': 'No internet connection',
    'error_connectionDesc': 'Please check your network and try again.',
    'error_generic': 'Something went wrong',
    'error_genericDesc': 'Please try again later.',

    // Connectivity Banner (mounted globally in main_navigation.dart)
    'connectivity_offline_title': 'You are offline',
    'connectivity_offline_msg': 'Some content may be unavailable.',

    // Phase 3.2 — remaining screens (nav, leaderboard, splash, materials)
    'nav_ranks': 'Ranks',
    'exit_title': 'Exit App?',
    'exit_confirm': 'Do you really want to exit ExamVault?',
    'exit_button': 'Exit',
    'leaderboard_title': 'Leaderboard',
    'leaderboard_weekly': 'Weekly',
    'leaderboard_monthly': 'Monthly',
    'leaderboard_allTime': 'All Time',
    'leaderboard_you': 'YOU',
    'leaderboard_stale':
        'Showing cached rankings — reconnect to refresh.',
    'leaderboard_empty': 'No leaderboard data available',
    'leaderboard_tests': 'tests',
    'leaderboard_avg': 'avg',
    'splash_tagline': "India's #1 MCQ Mock Test platform",
    'splash_taglineShort': 'MCQ Mock Test Platform',
    'material_offlineTitle': 'You are offline',
    'material_offlineDesc': 'Connect to the internet to load study materials.',
    'material_emptyDesc':
        'New content will appear here automatically when the admin adds it.',
    'material_premiumTitle': 'Premium Content',
    'material_premiumDesc':
        '"{title}" is a premium study material. Upgrade to ExamVault Premium to access all papers, notes, and syllabi.',
    'material_pagesSuffix': 'pages',
    'material_typePreviousPaper': 'Previous Papers',
    'material_typeNotes': 'Study Notes',
    'material_typeSyllabus': 'Syllabus',
    'material_pluralPreviousPaper': 'Papers',
    'material_pluralNotes': 'Notes',
    'material_pluralSyllabus': 'Syllabi',
    'material_stale': 'Showing cached content — reconnect to refresh.',
    'material_emptyTitle': 'No {type} available yet',
    'category_noSubjectsTitle': 'No subjects available yet',
    'category_noSubjectsDesc': 'Subjects for this category will appear here soon.',
    'category_errorTitle': "Couldn't load subjects",
    'category_errorDesc': 'Please check your internet connection and try again.',
    'dailyQuiz_emptyTitle': 'No daily quizzes available yet',
    'dailyQuiz_emptyDesc': 'Check back soon for new quizzes!',
    'dailyQuiz_errorTitle': 'Could not load daily quizzes',
    'dailyQuiz_errorDesc': 'Please try again later.',
    // Daily Quiz Screen — labels & buttons (Critical #7 fix)
    'daily_quiz_title': 'Daily Quiz',
    'daily_quiz_today': "Today's Quiz",
    'daily_quiz_previous': 'Previous Quizzes',
    'daily_quiz_streak': 'day streak',
    'daily_quiz_premium_badge': 'PREMIUM',
    'daily_quiz_start': 'Start Quiz',
    'daily_quiz_start_short': 'Start',
    'daily_quiz_no_today': 'No quiz for today yet',
    'daily_quiz_check_later': 'Check back later!',
    // Daily Quiz — streak card motivational messages (Task ma l10n completion).
    // Rendered on the daily quiz streak card via inline tr() lookup (the
    // streak_helper.streakMessage() function returns English-only strings;
    // daily_quiz_screen.dart inlines the same 4-way condition using these
    // keys so the message honors the user's LanguageMode preference).
    'daily_quiz_streak_msg_start_active':
        'Great start! Take a quiz to begin a streak.',
    'daily_quiz_streak_msg_start_inactive':
        "Take today's quiz to start a new streak.",
    'daily_quiz_streak_msg_active_fire':
        "You're on fire! Come back tomorrow to extend it.",
    'daily_quiz_streak_msg_keep_alive':
        "Take today's quiz to keep your streak alive.",

    // Current Affairs Screen (Critical #8 + #9 fix)
    'ca_title': 'Current Affairs',
    'ca_all_categories': 'All Categories',
    'ca_select_category': 'Select Category',
    'ca_clear_date': 'Clear Date',
    'ca_no_results': 'No current affairs match your filters',

    // Test Instructions Screen
    'instr_title': 'Test Instructions',
    'instr_questions': 'Questions',
    'instr_minutes': 'Minutes',
    'instr_marks': 'Marks',
    'instr_markingScheme': 'Marking Scheme',
    'instr_correctAnswer': 'Correct Answer',
    'instr_wrongAnswer': 'Wrong Answer',
    'instr_notAttempted': 'Not Attempted',
    'instr_zeroMarks': '0 marks',
    'instr_questionPalette': 'Question Palette',
    'instr_generalInstructions': 'General Instructions',
    'instr_timerWarning': 'The timer starts as soon as you tap "Agree & Start Test" below — the test auto-submits when time runs out.',
    'instr_tapOption': 'Tap an option to select your answer. Tap it again to deselect / clear.',
    'instr_navigate': 'Use Next / Previous or the question palette to move between questions freely.',
    'instr_internet': 'Make sure you have a stable internet connection before starting.',
    'instr_agree': 'I have read and understood the instructions above.',
    'instr_agreeStart': 'Agree & Start Test',

    // Category Detail Screen — paywall strings
    'cat_premiumPack': 'Premium Exam Pack',
    'cat_signInToUnlock': 'Sign in to unlock "{name}" and all its tests.',
    'cat_unlockFor': 'Unlock "{name}" and all its tests for ₹{price}, or upgrade to Premium for unlimited access.',
    'cat_subscribeToUnlock': 'Subscribe to Premium to unlock "{name}" and all its tests.',
    'cat_signInBtn': 'Sign In to Unlock',
    'cat_unlockExam': 'Unlock this exam (₹{price})',
    'cat_goPremium': 'Go Premium',
    'cat_maybeLater': 'Maybe later',
    'cat_rollingOut': 'This feature is being rolled out.',
    'cat_updateApp': 'Please update the app soon to access premium content in {name}.',
    'cat_explorePremium': 'Explore Premium',
    'cat_openExam': 'Open Exam',
    'cat_signInToPurchase': 'Please sign in to make a purchase.',
    'cat_paymentTakingLong': 'Payment is taking longer than expected. Check "My Purchases" to see if it succeeded.',
    'cat_checkPurchases': 'Check My Purchases',
    'cat_paymentFailed': 'Payment failed. Please try again.',

    // Auth — Forgot Password flow (login_screen.dart)
    'auth_forgot_password': 'Forgot Password?',
    'auth_enter_email_first': 'Please enter your email first',
    'auth_reset_email_sent': 'Password reset email sent — check your inbox',
    'auth_reset_failed': 'Could not send reset email',

    // Login Screen (Critical #2)
    'login_welcome_title': 'Welcome to ExamVault',
    'login_welcome_subtitle': 'Sign in to continue your exam preparation',
    'login_method_mobile': 'Mobile',
    'login_method_email': 'Email',
    'login_otp_sending': 'Sending OTP...',
    'login_otp_sending_subtitle': 'Please wait a moment',
    'login_otp_verifying': 'Verifying...',
    'login_otp_verifying_subtitle':
        'Firebase is verifying your number. This may take a few seconds.',
    'login_otp_still_working': 'Still working...',
    'login_otp_still_working_subtitle':
        'Verification in progress. If a verification page opens, please complete it — the OTP will arrive afterwards.',
    'login_otp_taking_long': 'Taking longer than usual...',
    'login_otp_taking_long_subtitle':
        'There may be a network issue. Please be patient, or try again in a moment.',
    'login_otp_unavailable_title': 'Mobile OTP is currently unavailable',
    'login_otp_unavailable_msg':
        'Please use Email sign-in — tap the "Email" tab above.',
    'login_mobile_number': 'Mobile Number',
    'login_enter_otp': 'Enter OTP sent to',
    'login_verify_otp_login': 'Verify OTP & Login',
    'login_send_otp': 'Send OTP',
    'login_resend_otp': 'Resend OTP',
    'login_change_number': 'Change number',
    'login_full_name': 'Full Name',
    'login_email': 'Email',
    'login_password': 'Password',
    'login_sign_up': 'Sign Up',
    'login_sign_in': 'Sign In',
    'login_have_account_signin': 'Already have an account? Sign In',
    'login_no_account_signup': "Don't have an account? Sign Up",
    'login_enter_phone': 'Please enter phone number',
    'login_invalid_phone': 'Please enter a valid 10-digit mobile number',
    'login_otp_sent_to': 'OTP sent to',
    'login_otp_auto_verified': 'OTP auto-verified! Logging you in...',
    'login_enter_6_digit_otp': 'Please enter the 6-digit OTP',
    'login_request_otp_first': 'Please request OTP first',
    'login_fill_all_fields': 'Please fill all fields',
    'login_invalid_email': 'Please enter a valid email address',
    'login_password_too_short': 'Password must be at least 6 characters',
    'login_enter_name': 'Please enter your name',

    // Test Series Screen (Critical #3)
    'test_series_title': 'Test Series',
    'my_categories': 'My Categories',
    'test_series_tab_practice': 'Practice',
    'test_series_tab_subjectwise': 'Subject-wise',
    'test_series_no_tests_in_categories':
        'No tests in your selected categories',
    'test_series_edit_categories': 'Edit My Categories',
    'test_series_completed': 'Completed',
    'test_series_qs_suffix': 'Qs',
    'test_series_no_subjects': 'No subjects available',
    'test_series_no_subjects_in_categories':
        'No subjects in your selected categories',
    'test_series_test_singular': 'Test',
    'test_series_test_plural': 'Tests',
    'test_type_mock': 'MOCK TEST',
    'test_type_previous_year': 'PREVIOUS YEAR',
    'test_type_daily_quiz': 'DAILY QUIZ',
    'test_type_practice': 'PRACTICE',
    'test_type_subjectwise': 'SUBJECT WISE',
    'test_difficulty_easy': 'EASY',
    'test_difficulty_medium': 'MEDIUM',
    'test_difficulty_hard': 'HARD',

    // Notifications Screen (Critical #5)
    'notifications_title': 'Notifications',
    'notifications_mark_all_read': 'Mark All Read',
    'notifications_empty': 'No notifications yet',

    // Announcements Screen (Critical #6)
    'announcements_title': 'Announcements',
    'announcements_empty': 'No announcements yet',
    'announcements_live_badge': 'LIVE',
    'announcements_pinned_badge': 'Pinned',
    'announcements_min_ago': 'm ago',
    'announcements_hour_ago': 'h ago',
    'announcements_day_ago': 'd ago',

    // Onboarding — Category Selection Screen (Critical #7)
    'onboarding_welcome_title': 'Welcome to ExamVault!',
    'onboarding_welcome_desc':
        'Which exams are you preparing for? Pick as many as you like — your Home screen will focus on these.',
    'onboarding_no_categories': 'No categories available yet.',
    'onboarding_selected': 'selected',
    'onboarding_skip_for_now': 'Skip for now',

    // ─── Issue #19: Settings — Notifications + Logout ───
    'settings_notif_push': 'Push notifications',
    'settings_notif_push_subtitle': 'Master switch for all notifications',
    'settings_notif_announcements': 'Exam announcements',
    'settings_notif_announcements_subtitle':
        'New exam notifications & updates',
    'settings_notif_daily_quiz': 'Daily quiz reminders',
    'settings_notif_daily_quiz_subtitle':
        'Daily practice reminder notifications',
    'settings_logout': 'Logout',
    'settings_logout_confirm_title': 'Logout?',
    'settings_logout_confirm_msg':
        'You will be signed out of your account. You can sign back in anytime.',
    'settings_logout_confirm_button': 'Logout',
    'settings_cancel': 'Cancel',

    // ─── Issue #18: PDF Viewer ───
    'pdf_opening': 'Opening PDF...',
    'pdf_open_failed': 'Could not open PDF',
    'pdf_no_viewer': 'No PDF viewer app found on this device.',
    'pdf_open_in_browser': 'Open in Browser',
    'pdf_open_manually':
        'If the PDF does not open automatically, tap the button below.',

    // ─── Issue #20: Test History ───
    'history_title': 'Test History',
    'history_filter_all': 'All',
    'history_filter_passed': 'Passed',
    'history_filter_failed': 'Failed',
    'history_empty_title': 'No test history yet',
    'history_empty_msg': 'Take your first test to see your performance here.',
    'history_reattempt': 'Re-attempt',
    'history_rank': 'Rank',
    'history_accuracy': 'Accuracy',
    'history_time_taken': 'Time',
    'history_score': 'Score',
    'history_no_results': 'No results match this filter.',
    'history_loading_test': 'Opening test…',
    'history_test_not_found': 'Test not found. It may have been removed.',

    // ─── Issue #22: Invoice download ───
    'invoice_downloading': 'Downloading invoice...',
    'invoice_download_success': 'Invoice downloaded. Opening...',
    'invoice_download_failed':
        'Could not download invoice. Check your connection and try again.',
    'invoice_open_failed':
        'Invoice downloaded but no PDF viewer is available. Open it from your Files app.',

    // ─── Issue #23: Premium current-plan + Restore ───
    'premium_current_plan': 'You\'re a Premium member',
    'premium_current_plan_msg': 'Premium active until {date}',
    'premium_current_plan_no_expiry': 'Premium is active on your account.',
    'premium_manage': 'Manage Subscription',
    'premium_manage_msg': 'Contact support to manage your subscription.',
    'premium_restore': 'Restore Purchases',
    'premium_restore_success': 'Premium restored successfully!',
    'premium_restore_none': 'No active subscription found.',
    'premium_restore_loading': 'Checking your subscription...',

    // ─── Issue #30: Razorpay retry ───
    'contact_support': 'Contact Support',
    'payment_failed_retry_msg':
        'Payment failed. Tap Retry to try again or Contact Support for help.',
  };

  static const Map<String, String> assamese = {
    // Generic
    'loading': 'লোড হৈছে...',
    'retry': 'পুনঃ চেষ্টা',
    'refresh': 'ৰিফ্ৰেশ্ব',
    'cancel': 'বাতিল',
    'save': 'সংৰক্ষণ',
    'done': 'সম্পূৰ্ণ',
    'continue': 'আগবাঢ়ক',
    'back': 'উভতি যাওক',
    'search': 'সন্ধান',
    'error': 'কিবা ভুল হৈছে',
    'empty': 'এতিয়া একো নাই',
    'seeAll': 'সকলো চাওক',
    'viewAll': 'সকলো চাওক',
    'new': 'নতুন',
    'free': 'ফ্ৰী',
    'premium': 'প্ৰিমিয়াম',
    'unlock': 'আনলক',
    'startNow': 'এতিয়া আৰম্ভ কৰক',
    'getStarted': 'আৰম্ভ কৰক',

    // Bottom Nav
    'nav_home': 'মূল পৃষ্ঠা',
    'nav_exams': 'পৰীক্ষা',
    'nav_practice': 'অনুশীলন',
    'nav_profile': 'প্ৰফাইল',

    // Home Screen
    'home_welcome': ' লৈ স্বাগতম',
    'home_subtitle': 'আজি পৰীক্ষাৰ বাবে প্ৰস্তুত হওঁক',
    'home_categories': 'পৰীক্ষাৰ শিতান',
    'home_popular': 'জনপ্ৰিয় বিষয়',
    'home_upcoming': 'আগন্তুক পৰীক্ষা',
    'home_currentAffairs': 'সাম্প্ৰতিক ঘটনা',
    'home_announcements': 'ঘোষণা',
    'home_dailyQuiz': 'দৈনিক কুইজ',
    'home_streak': 'দিনৰ ধাৰাবাহিকতা',
    'home_continueLearning': 'শিক্ষা আগবঢ়াওক',
    'home_exploreExams': 'পৰীক্ষা চাওক',
    // Home Screen — Phase 3.1 modernization additions
    'home_guestMsg':
        'অতিথি হিচাপে ব্ৰাউজ কৰি আছে। প্ৰিমিয়াম পৰীক্ষা আনলক কৰিবলৈ আৰু অগ্ৰগতি সংৰক্ষণ কৰিবলৈ চাইন ইন কৰক।',
    'home_signIn': 'চাইন ইন কৰক',
    'home_quickMock': 'মক টেষ্ট',
    'home_quickUpcoming': 'আগন্তুক',
    'home_quickBookmarks': 'বুকমাৰ্ক',
    'home_apply': 'আবেদন',
    'home_important': 'গুৰুত্বপূৰ্ণ',
    'home_updates': 'আপডেট',
    'home_premiumHeadline': 'ExamVault প্ৰিমিয়াম আনলক কৰক',
    'home_premiumCta': 'এতিয়া আপগ্ৰেড কৰক',
    'home_premiumSubtitle2':
        'আনলিমিটেড পৰীক্ষা, বিস্তৃত সমাধান আৰু অধিক পাওক',
    'home_noCategories': 'কোনো শিতান উপলব্ধ নাই',
    'home_noSubjects': 'এতিয়ালৈকে কোনো বিষয় নাই',
    'home_noUpcoming': 'কোনো আগন্তুক পৰীক্ষা নিৰ্ধাৰিত নহয়',
    'home_noCurrentAffairs': 'কোনো সাম্প্ৰতিক ঘটনা উপলব্ধ নাই',
    'home_days': 'দিন',
    'home_daysAgo': 'দিন আগতে',

    // Category / Subjects
    'category_subjects': 'বিষয়সমূহ',
    'category_subjectsAvailable': 'বিষয় উপলব্ধ',
    'category_testsAvailable': 'পৰীক্ষা উপলব্ধ',
    'category_chooseSubject': 'অনুশীলন আৰম্ভ কৰিবলৈ এটা বিষয় বাছক',
    'category_allSubjects': 'সকলো বিষয়',
    'subject_tests': 'পৰীক্ষা',
    'subject_description': 'বিৱৰণ',
    'subject_startMock': 'এটা মক টেষ্ট আৰম্ভ কৰক',
    'subject_browseContent': 'এই বিষয়ৰ সামগ্ৰী চাওক',
    'subject_contentTypes': 'সামগ্ৰী',
    'subject_studyMaterial': 'অধ্যয়ন সামগ্ৰী',
    'subject_previousPapers': 'পূৰ্বৰ প্ৰশ্নপত্ৰ',
    'subject_studyNotes': 'অধ্যয়ন টোকা',
    'subject_syllabus': 'পাঠ্যক্ৰম',
    'subject_items': 'টা সামগ্ৰী',
    'subject_item': 'টা সামগ্ৰী',
    'subject_recent': 'শেহতীয়া কাৰ্য্য',
    'subject_exploreMore': 'অধিক চাওক',

    // Test List
    'test_all': 'সকলো',
    'test_free': 'ফ্ৰী',
    'test_premium': 'প্ৰিমিয়াম',
    'test_mock': 'মক',
    'test_previousYear': 'পূৰ্বৰ বছৰ',
    'test_startTest': 'পৰীক্ষা আৰম্ভ কৰক',
    'test_unlockPremium': 'প্ৰিমিয়ামেৰে আনলক কৰক',
    'test_buyNow': 'এতিয়া কিনক',
    'test_duration': 'মিনিট',
    'test_marks': 'নম্বৰ',
    'test_questions': 'প্ৰশ্ন',
    'test_attempts': 'বাৰ চেষ্টা',
    'test_negativeMarking': 'ঋণাত্মক নম্বৰ',
    'test_year': 'বছৰ',
    'test_noTests': 'কোনো পৰীক্ষা নাই',
    'test_noTestsDesc': 'এই বিষয়ৰ পৰীক্ষা শীঘ্ৰে ইয়াত আহিব।',
    'test_checkBackSoon': 'শীঘ্ৰে আকৌ চাওক!',
    'test_loadingTests': 'পৰীক্ষা লোড হৈছে...',
    'test_noMatchingTests': 'এই ফিল্টাৰৰ সৈতে কোনো পৰীক্ষা নাই',
    'test_noMatchingTestsDesc': 'এটা ভিন্ন ফিল্টাৰ চেষ্টা কৰক।',
    'test_clearFilter': 'ফিল্টাৰ আঁততাওক',
    'test_unableToLoad': 'পৰীক্ষা লোড কৰিব নোৱাৰি।',
    'test_unableToLoadDesc': 'অনুগ্ৰহ কৰি আপোনাৰ সংযোগ পৰীক্ষা কৰি পুনঃ চেষ্টা কৰক।',
    'test_unlockSubject': '{subject} ৰ সকলো পৰীক্ষা আনলক কৰক',
    'test_unlockSubjectDesc': 'এই বিষয়ৰ প্ৰতিটো পৰীক্ষাৰ বাবে এক্সেছ পাওক',
    'test_unlockTest': '"{title}" আনলক কৰক',
    'test_buyOrPremiumDesc':
        'এই পৰীক্ষা কিনক বা প্ৰিমিয়ামলৈ আপগ্ৰেড কৰক। সকলো পেমেণ্ট সুৰক্ষিত আৰু যাচাই কৰা।',
    'test_premiumOnlyDesc':
        'আনলিমিটেড এক্সেছৰ বাবে প্ৰিমিয়ামলৈ আপগ্ৰেড কৰক। সকলো পেমেণ্ট সুৰক্ষিত আৰু যাচাই কৰা।',
    'test_buyThisTest': 'এই পৰীক্ষা কিনক',
    'test_attemptAnytime': 'যেতিয়া বিচাৰে চেষ্টা কৰক',
    'test_unlimitedAccess': 'সকলোৰে বাবে আনলিমিটেড এক্সেছ',
    'test_maybeLater': 'পিছত হয়তো',
    'test_paymentTakingLong':
        'পেমেণ্ট অপেক্ষাতকৈ বেছি সময় লাগিছে। ই সফল হৈছে নে নাই পৰীক্ষা কৰিবলৈ "মোৰ ক্ৰয়" চাওক।',
    'test_preparingPayment': 'পেমেণ্ট প্ৰস্তুত কৰি আছে...',
    'test_verifyingPayment': 'পেমেণ্ট যাচাই কৰি আছে...',
    'test_paymentFailedPrefix': 'পেমেণ্ট ব্যৰ্থ:',
    'test_paymentFailedGeneric': 'অনুগ্ৰহ কৰি পুনঃ চেষ্টা কৰক।',
    'test_openTest': 'পৰীক্ষা খোলক',
    'test_signInToPurchase': 'ক্ৰয় কৰিবলৈ অনুগ্ৰহ কৰি চাইন ইন কৰক।',
    'test_subjectPackPrefix': 'বিষয় পেক: ',
    'test_premiumOnlyHint': 'এই পৰীক্ষা দিবলৈ প্ৰিমিয়ামত ছাবস্ক্ৰাইব কৰক।',
    'test_paidHint': 'এই পৰীক্ষা কিনক বা প্ৰিমিয়ামলৈ আপগ্ৰেড কৰক।',

    // Take Test
    'test_question': 'প্ৰশ্ন',
    'test_of': 'ৰ',
    'test_timeLeft': 'বাকী সময়',
    'test_previous': 'আগৰ',
    'test_next': 'পৰৱৰ্তী',
    'test_markReview': 'পৰ্যালোচনাৰ বাবে চিহ্নিত',
    'test_submit': 'পৰীক্ষা জমা দিয়ক',
    'test_saveNext': 'সংৰক্ষণ আৰু পৰৱৰ্তী',
    'test_clear': 'মচক',
    'test_palette': 'প্ৰশ্ন পেলেট',
    'test_answered': 'উত্তৰ দিছে',
    'test_notAnswered': 'উত্তৰ দিয়া নাই',
    'test_marked': 'চিহ্নিত',
    'test_notVisited': 'দেখা নাই',
    // Take Test — v2 modernization additions
    'test_close': 'বন্ধ কৰক',
    'test_exitTitle': 'পৰীক্ষা বন্ধ কৰিব?',
    'test_exitConfirm': 'আপোনাৰ অগ্ৰগতি হেৰাব। আপুনি নিশ্চিতনে?',
    'test_exit': 'ওলাই যাওক',
    'test_noQuestions': 'এই পৰীক্ষাৰ বাবে এতিয়ালৈকে কোনো প্ৰশ্ন নাই।',
    'test_noQuestionsDesc': 'প্ৰশ্ন প্ৰকাশ পালে ইয়াত দেখা যাব।',
    'test_goBack': 'উভতি যাওক',
    'test_paywallTitle': 'প্ৰিমিয়াম পৰীক্ষা',
    'test_paywallGuestDesc':
        'এই পৰীক্ষা আনলক কৰিবলৈ চাইন ইন কৰক। ফ্ৰী পৰীক্ষা একাউণ্ট অবিহনে উপলব্ধ।',
    'test_paywallBuyDesc':
        'এই পৰীক্ষা কিনক বা প্ৰিমিয়ামলৈ আপগ্ৰেড কৰক।',
    'test_paywallPremiumDesc': 'এই পৰীক্ষা দিবলৈ প্ৰিমিয়ামলৈ আপগ্ৰেড কৰক।',
    'test_paywallRollingOut':
        'লাইভ এক্সেছ যাচাই আৰম্ভ হৈছে। অনুগ্ৰহ কৰি শীঘ্ৰে এপ্ আপডেট কৰক।',
    'test_signInToUnlock': 'আনলক কৰিবলৈ চাইন ইন কৰক',
    'test_buyFor': '₹{price}ৰ বাবে কিনক',
    'test_goPremium': 'প্ৰিমিয়াম লওক',
    'test_checkPurchases': 'মোৰ ক্ৰয় চাওক',
    'test_bookmarkSaved': 'বুকমাৰ্ক সংৰক্ষিত',
    'test_bookmarkRemoved': 'বুকমাৰ্ক আঁতৰোৱা হ’ল',
    'test_bookmarkFailed': 'বুকমাৰ্ক আপডেট কৰিব নোৱাৰি। পুনঃ চেষ্টা কৰক।',
    'test_bookmarkPermission':
        'বুকমাৰ্ক ত্ৰুটি: অনুমতি নাই। এডমিনে Firestore rules ডিপ্লয় কৰিব লাগিব।',
    'test_bookmarkAddTooltip': 'এই পৰীক্ষা বুকমাৰ্ক কৰক',
    'test_bookmarkRemoveTooltip': 'বুকমাৰ্ক আঁতাওক',
    // Take Test — resumption + lifecycle anti-cheat (Critical #4)
    'test_resume_title': 'পৰীক্ষা পুনৰ আৰম্ভ কৰিব নেকি?',
    'test_resume_msg':
        'আপোনাৰ এটা অসম্পূৰ্ণ পৰীক্ষা আছে। আপুনি য’ত এৰিছিল তাৰ পৰা পুনৰ আৰম্ভ কৰিব বিচাৰে নেকি?',
    'test_resume_button': 'পুনৰ আৰম্ভ কৰক',
    'test_restart_button': 'নতুনকৈ আৰম্ভ কৰক',
    'test_paused_msg':
        'আপুনি নাছিল সময়ত পৰীক্ষা বিৰতি লৈছিল। টাইমাৰ পুনৰ আৰম্ভ কৰা হ’ল।',

    // Result
    'result_score': 'আপোনাৰ নম্বৰ',
    'result_correct': 'শুদ্ধ',
    'result_wrong': 'ভুল',
    'result_skipped': 'এৰি যোৱা',
    'result_timeTaken': 'সময় লগা',
    'result_rank': 'আপোনাৰ স্থান',
    'result_retake': 'পুনৰ পৰীক্ষা',
    'result_share': 'ফলাফল শ্বেয়াৰ',
    'result_review': 'উত্তৰ পৰ্যালোচনা',
    'result_excellent': 'অসাধাৰণ! 🎉',
    'result_good': 'ভাল কাম! 👏',
    'result_keepGoing': 'অনুশীলন চালিয়ে থাকক! 💪',
    'result_correctAnswer': 'শুদ্ধ উত্তৰ',
    'result_yourAnswer': 'আপোনাৰ উত্তৰ',
    'result_explanation': 'ব্যাখ্যা',
    'result_testResult': 'পৰীক্ষাৰ ফলাফল',
    'result_answerReview': 'উত্তৰ পৰ্যালোচনা',

    // Profile
    'profile_edit': 'প্ৰফাইল সম্পাদনা',
    'profile_bookmarks': 'বুকমাৰ্ক',
    'profile_testHistory': 'পৰীক্ষাৰ ইতিহাস',
    'profile_settings': 'ছেটিংছ',
    'profile_help': 'সহায় আৰু সমৰ্থন',
    'profile_logout': 'লগআউট',
    'profile_premium': 'প্ৰিমিয়াম লওক',
    'profile_myPurchases': 'মোৰ ক্ৰয়',

    // Premium
    'premium_title': 'প্ৰিমিয়াম লওক',
    'premium_subtitle': 'সকলো পৰীক্ষা আৰু সুবিধা আনলক কৰক',
    'premium_allTests': 'সকলো মক টেষ্ট',
    'premium_noAds': 'বিজ্ঞাপন-মুক্ত অভিজ্ঞতা',
    'premium_detailedSolutions': 'বিস্তৃত সমাধান',
    'premium_performanceAnalytics': 'কাৰ্য্যক্ষমতা বিশ্লেষণ',
    'premium_priority': 'অগ্ৰাধিকাৰ সমৰ্থন',
    'premium_subscribe': 'এতিয়া সদস্যতা লওক',
    'premium_perMonth': '/মাহ',
    'premium_perYear': '/বছৰ',

    // Settings
    'settings_language': 'ভাষা',
    'settings_english': 'English',
    'settings_assamese': 'অসমীয়া',
    'settings_both': 'দুয়ো',
    'settings_theme': 'থিম',
    'settings_light': 'পোহৰ',
    'settings_dark': 'আন্ধাৰ',
    'settings_system': 'চিস্টেম',
    'settings_notifications': 'জাননী',

    // Account / Delete Account (Google Play Data Deletion policy — Jan 2024)
    'settings_account': 'একাউণ্ট',
    'settings_delete_account': 'একাউণ্ট ডিলিট কৰক',
    'settings_delete_account_subtitle':
        'আপোনাৰ একাউণ্ট আৰু ডাটা স্থায়ীভাৱে ডিলিট কৰক',
    'settings_delete_account_confirm_title': 'একাউণ্ট ডিলিট কৰিব নেকি?',
    'settings_delete_account_confirm_msg':
        'ইয়াৰ ফলত আপোনাৰ একাউণ্ট, পৰীক্ষাৰ ইতিহাস, বুকমাৰ্ক আৰু ক্ৰয় স্থায়ীভাৱে ডিলিট হ\'ব। এই কাৰ্য পূৰণ কৰিব নোৱাৰি।',
    'settings_delete_account_type_to_confirm': 'নিশ্চিত কৰিবলৈ DELETE লিখক',
    'settings_delete_account_final_button': 'হয়, মোৰ একাউণ্ট ডিলিট কৰক',
    'settings_delete_account_cancel': 'বাতিল কৰক',
    'settings_delete_account_success':
        'একাউণ্ট ডিলিট কৰা হ\'ল। আপুনি ছাইন আউট হৈছে।',
    'settings_delete_account_failed': 'একাউণ্ট ডিলিট কৰিব পৰা নগ\'ল',

    // About / Legal
    'about': 'বিষয়ে',
    'appVersion': 'এপ্ সংস্কৰণ',
    'privacyPolicy': 'গোপনীয়তা নীতি',
    'termsConditions': 'চৰ্তাৱলী',
    'refundPolicy': 'ৰিফাণ্ড নীতি',

    // Empty / Error states
    'empty_bookmarks': 'এতিয়া কোনো বুকমাৰ্ক নাই',
    'empty_bookmarksDesc': 'পিছত পৰ্যালোচনা কৰিবলৈ প্ৰশ্ন বুকমাৰ্ক কৰক।',
    'empty_history': 'এতিয়ালৈকে কোনো পৰীক্ষাৰ ইতিহাস নাই',
    'empty_historyDesc': 'প্ৰথম পৰীক্ষা দিলে ইয়াত দেখা যাব।',
    'error_connection': 'ইন্টাৰনেট সংযোগ নাই',
    'error_connectionDesc': 'অনুগ্ৰহ কৰি নেটৱৰ্ক পৰীক্ষা কৰি পুনৰ চেষ্টা কৰক।',
    'error_generic': 'কিবা ভুল হৈছে',
    'error_genericDesc': 'অনুগ্ৰহ কৰি পিছত পুনৰ চেষ্টা কৰক।',

    // Connectivity Banner (mounted globally in main_navigation.dart)
    'connectivity_offline_title': 'আপুনি অফলাইন',
    'connectivity_offline_msg': 'কিছু কনটেন্ট অনুপলব্ধ হ\'ব পাৰে।',

    // Phase 3.2 — remaining screens (nav, leaderboard, splash, materials)
    'nav_ranks': 'স্থান',
    'exit_title': 'এপ্ বন্ধ কৰিব?',
    'exit_confirm': 'আপুনি সঁচাকৈ ExamVault বন্ধ কৰিব বিচাৰে নে?',
    'exit_button': 'ওলাই যাওক',
    'leaderboard_title': "লিডাৰব'ৰ্ড",
    'leaderboard_weekly': 'সাপ্তাহিক',
    'leaderboard_monthly': 'মাহিক',
    'leaderboard_allTime': 'সৰ্বকাল',
    'leaderboard_you': 'আপুনি',
    'leaderboard_stale':
        'কেশ্ব কৰা স্থান দেখুওৱা হৈছে — ৰিফ্ৰেশ্ব কৰিবলৈ পুনঃ সংযোগ কৰক।',
    'leaderboard_empty': "কোনো লিডাৰব'ৰ্ড তথ্য নাই",
    'leaderboard_tests': 'পৰীক্ষা',
    'leaderboard_avg': 'গড়',
    'splash_tagline': 'ভাৰতৰ #1 MCQ মক টেষ্ট প্লেটফৰ্ম',
    'splash_taglineShort': 'MCQ মক টেষ্ট প্লেটফৰ্ম',
    'material_offlineTitle': 'আপুনি অফলাইন',
    'material_offlineDesc':
        'অধ্যয়ন সামগ্ৰী লোড কৰিবলৈ ইন্টাৰনেট সংযোগ কৰক।',
    'material_emptyDesc':
        'এডমিনে যোগ কৰিলে নতুন সামগ্ৰী ইয়াত স্বয়ংক্ৰিয়ভাৱে দেখা যাব।',
    'material_premiumTitle': 'প্ৰিমিয়াম সামগ্ৰী',
    'material_premiumDesc':
        '"{title}" এটা প্ৰিমিয়াম অধ্যয়ন সামগ্ৰী। সকলো প্ৰশ্নপত্ৰ, টোকা আৰু পাঠ্যক্ৰম এক্সেছ কৰিবলৈ ExamVault প্ৰিমিয়ামলৈ আপগ্ৰেড কৰক।',
    'material_pagesSuffix': 'পৃষ্ঠা',
    'material_typePreviousPaper': 'আগৰ প্ৰশ্নপত্ৰ',
    'material_typeNotes': 'অধ্যয়ন টোকা',
    'material_typeSyllabus': 'পাঠ্যক্ৰম',
    'material_pluralPreviousPaper': 'প্ৰশ্নপত্ৰ',
    'material_pluralNotes': 'টোকা',
    'material_pluralSyllabus': 'পাঠ্যক্ৰম',
    'material_stale': 'কেশ্বড সামগ্ৰী দেখুওৱা হৈছে — ৰিফ্ৰেশ কৰিবলৈ সংযোগ কৰক।',
    'material_emptyTitle': 'এতিয়াও কোনো {type} উপলব্ধ নহয়',
    'category_noSubjectsTitle': 'এতিয়াও কোনো বিষয় উপলব্ধ নহয়',
    'category_noSubjectsDesc': 'এই শ্ৰেণীৰ বিষয়বোৰ শীঘ্ৰে ইয়াত দেখা যাব।',
    'category_errorTitle': 'বিষয়বোৰ লোড কৰিব পৰা নগ\'ল',
    'category_errorDesc': 'অনুগ্ৰহ কৰি আপোনাৰ ইন্টাৰনেট সংযোগ পৰীক্ষা কৰি পুনৰ চেষ্টা কৰক।',
    'dailyQuiz_emptyTitle': 'এতিয়াও কোনো দৈনিক কুইজ উপলব্ধ নহয়',
    'dailyQuiz_emptyDesc': 'নতুন কুইজৰ বাবে শীঘ্ৰে আকৌ আহক!',
    'dailyQuiz_errorTitle': 'দৈনিক কুইজ লোড কৰিব পৰা নগ\'ল',
    'dailyQuiz_errorDesc': 'অনুগ্ৰহ কৰি পিছত পুনৰ চেষ্টা কৰক।',
    // Daily Quiz Screen — labels & buttons (Critical #7 fix)
    'daily_quiz_title': 'দৈনিক কুইজ',
    'daily_quiz_today': 'আজিৰ কুইজ',
    'daily_quiz_previous': 'পূৰ্বৰ কুইজবোৰ',
    'daily_quiz_streak': 'দিনৰ ধাৰা',
    'daily_quiz_premium_badge': 'প্ৰিমিয়াম',
    'daily_quiz_start': 'কুইজ আৰম্ভ কৰক',
    'daily_quiz_start_short': 'আৰম্ভ',
    'daily_quiz_no_today': 'আজিৰ বাবে এতিয়াও কুইজ নাই',
    'daily_quiz_check_later': 'পিছত আকৌ চাওক!',
    // Daily Quiz — streak card motivational messages (Task ma l10n completion).
    'daily_quiz_streak_msg_start_active':
        'চমৎকাৰ আৰম্ভ! এটা ষ্ট্ৰিক আৰম্ভ কৰিবলৈ কুইজ দিয়ক।',
    'daily_quiz_streak_msg_start_inactive':
        'নতুন ষ্ট্ৰিক আৰম্ভ কৰিবলৈ আজিৰ কুইজ দিয়ক।',
    'daily_quiz_streak_msg_active_fire':
        'আপুনি দুৰন্ত! ইয়াক আগুৱাই নিবলৈ কাইলৈ উভতি আহক।',
    'daily_quiz_streak_msg_keep_alive':
        'আপোনাৰ ষ্ট্ৰিক জীয়াই ৰাখিবলৈ আজিৰ কুইজ দিয়ক।',

    // Current Affairs Screen (Critical #8 + #9 fix)
    'ca_title': 'চলিত পৰিক্ৰমা',
    'ca_all_categories': 'সকলো শ্ৰেণী',
    'ca_select_category': 'শ্ৰেণী বাছনি কৰক',
    'ca_clear_date': 'তাৰিখ আঁতৰাওক',
    'ca_no_results': 'আপোনাৰ ফিল্টাৰৰ সৈতে কোনো চলিত পৰিক্ৰমা নাই',

    // Test Instructions Screen
    'instr_title': 'পৰীক্ষাৰ নিৰ্দেশনা',
    'instr_questions': 'প্ৰশ্ন',
    'instr_minutes': 'মিনিট',
    'instr_marks': 'নম্বৰ',
    'instr_markingScheme': 'নম্বৰ প্ৰণালী',
    'instr_correctAnswer': 'শুদ্ধ উত্তৰ',
    'instr_wrongAnswer': 'ভুল উত্তৰ',
    'instr_notAttempted': 'চেষ্টা কৰা নাই',
    'instr_zeroMarks': '0 নম্বৰ',
    'instr_questionPalette': 'প্ৰশ্ন পেলেট',
    'instr_generalInstructions': 'সাধাৰণ নিৰ্দেশনা',
    'instr_timerWarning': 'আপুনি তলৰ "সন্মতি আৰু পৰীক্ষা আৰম্ভ কৰক" টিপাৰ লগেই টাইমাৰ আৰম্ভ হব — সময় শেষ হ\'লে পৰীক্ষা স্বয়ংক্ৰিয়ভাৱে জমা হব।',
    'instr_tapOption': 'এটা বিকল্প টিপি আপোনাৰ উত্তৰ বাছনি কৰক। আনটিপি কৰিলে নিৰ্বাচন মচি যাব।',
    'instr_navigate': 'পৰৱৰ্তী / আগৰ বুটাম বা প্ৰশ্ন পেলেট ব্যৱহাৰ কৰি মুক্তভাৱে প্ৰশ্নৰ মাজত সলনি কৰক।',
    'instr_internet': 'আৰম্ভ কৰাৰ আগতে আপোনাৰ ইন্টাৰনেট সংযোগ স্থিৰ আছে নে নিশ্চিত কৰক।',
    'instr_agree': 'মই ওপৰৰ নিৰ্দেশনাবোৰ পঢ়ি বুজিছোঁ।',
    'instr_agreeStart': 'সন্মতি আৰু পৰীক্ষা আৰম্ভ কৰক',

    // Category Detail Screen — paywall strings
    'cat_premiumPack': 'প্ৰিমিয়াম পৰীক্ষা পেক',
    'cat_signInToUnlock': '"{name}" আৰু ইয়াৰ সকলো পৰীক্ষা আনলক কৰিবলৈ চাইন ইন কৰক।',
    'cat_unlockFor': '"{name}" আৰু ইয়াৰ সকলো পৰীক্ষা ₹{price}ত আনলক কৰক, বা আনলিমিটেড এক্সেছৰ বাবে প্ৰিমিয়ামলৈ আপগ্ৰেড কৰক।',
    'cat_subscribeToUnlock': '"{name}" আৰু ইয়াৰ সকলো পৰীক্ষা আনলক কৰিবলৈ প্ৰিমিয়ামত সদস্যতা লওক।',
    'cat_signInBtn': 'আনলক কৰিবলৈ চাইন ইন কৰক',
    'cat_unlockExam': 'এই পৰীক্ষা আনলক কৰক (₹{price})',
    'cat_goPremium': 'প্ৰিমিয়াম লওক',
    'cat_maybeLater': 'পিছত হয়তো',
    'cat_rollingOut': 'এই সুবিধা আৰম্ভ কৰা হৈছে।',
    'cat_updateApp': '{name} ৰ প্ৰিমিয়াম সামগ্ৰী এক্সেছ কৰিবলৈ অনুগ্ৰহ কৰি শীঘ্ৰে এপ্ আপডেট কৰক।',
    'cat_explorePremium': 'প্ৰিমিয়াম চাওক',
    'cat_openExam': 'পৰীক্ষা খোলক',
    'cat_signInToPurchase': 'ক্ৰয় কৰিবলৈ অনুগ্ৰহ কৰি চাইন ইন কৰক।',
    'cat_paymentTakingLong': 'পেমেণ্ট অপেক্ষাতকৈ বেছি সময় লাগিছে। ই সফল হৈছে নে নাই পৰীক্ষা কৰিবলৈ "মোৰ ক্ৰয়" চাওক।',
    'cat_checkPurchases': 'মোৰ ক্ৰয় চাওক',
    'cat_paymentFailed': 'পেমেণ্ট ব্যৰ্থ। অনুগ্ৰহ কৰি পুনৰ চেষ্টা কৰক।',

    // Auth — Forgot Password flow (login_screen.dart)
    'auth_forgot_password': 'পাছৱৰ্ড পাহৰিলে নেকি?',
    'auth_enter_email_first': 'অনুগ্ৰহ কৰি প্ৰথমে আপোনাৰ ইমেইল লিখক',
    'auth_reset_email_sent': 'পাছৱৰ্ড ৰিছেট ইমেইল পঠিওৱা হ\'ল — আপোনাৰ ইনবক্স চাওক',
    'auth_reset_failed': 'ৰিছেট ইমেইল পঠিব পৰা নগ\'ল',

    // Login Screen (Critical #2)
    'login_welcome_title': 'ExamVault লৈ স্বাগতম',
    'login_welcome_subtitle': 'পৰীক্ষাৰ প্ৰস্তুতি আগবঢ়াবলৈ চাইন ইন কৰক',
    'login_method_mobile': 'মোবাইল',
    'login_method_email': 'ইমেইল',
    'login_otp_sending': 'OTP পঠিওৱা হৈছে...',
    'login_otp_sending_subtitle': 'অনুগ্ৰহ কৰি এক মুহূৰ্ত অপেক্ষা কৰক',
    'login_otp_verifying': 'প্ৰমাণ কৰি আছে...',
    'login_otp_verifying_subtitle':
        'Firebase আপোনাৰ নম্বৰ প্ৰমাণ কৰি আছে। কেইছেকেণ্ডমান সময় লাগিব পাৰে।',
    'login_otp_still_working': 'এতিয়াও কাম কৰি আছে...',
    'login_otp_still_working_subtitle':
        'প্ৰমাণীকৰণ চলি আছে। যদি এটা প্ৰমাণীকৰণ পৃষ্ঠা খোলে, অনুগ্ৰহ কৰি সম্পূৰ্ণ কৰক — তাৰ পিছত OTP আহিব।',
    'login_otp_taking_long': 'স্বাভাবিকতকৈ বেছি সময় লাগিছে...',
    'login_otp_taking_long_subtitle':
        'নেটৱৰ্কৰ সমস্যা হ\'ব পাৰে। অনুগ্ৰহ কৰি ধৈৰ্য্য ধৰক, বা এক মুহূৰ্ত পিছত পুনৰ চেষ্টা কৰক।',
    'login_otp_unavailable_title': 'মোবাইল OTP বৰ্তমান উপলব্ধ নহয়',
    'login_otp_unavailable_msg':
        'অনুগ্ৰহ কৰি ইমেইল চাইন ইন ব্যৱহাৰ কৰক — ওপৰৰ "ইমেইল" টেব টিপক।',
    'login_mobile_number': 'মোবাইল নম্বৰ',
    'login_enter_otp': 'এই নম্বৰলৈ পঠিওৱা OTP লিখক',
    'login_verify_otp_login': 'OTP প্ৰমাণ কৰি লগইন কৰক',
    'login_send_otp': 'OTP পঠিয়াওক',
    'login_resend_otp': 'OTP পুনৰ পঠিয়াওক',
    'login_change_number': 'নম্বৰ সলনি কৰক',
    'login_full_name': 'সম্পূৰ্ণ নাম',
    'login_email': 'ইমেইল',
    'login_password': 'পাছৱৰ্ড',
    'login_sign_up': 'ছাইন আপ কৰক',
    'login_sign_in': 'ছাইন ইন কৰক',
    'login_have_account_signin': 'আগৰেই একাউণ্ট আছে নেকি? ছাইন ইন কৰক',
    'login_no_account_signup': 'একাউণ্ট নাই নেকি? ছাইন আপ কৰক',
    'login_enter_phone': 'অনুগ্ৰহ কৰি ফোন নম্বৰ লিখক',
    'login_invalid_phone': 'অনুগ্ৰহ কৰি এটা বৈধ ১০-ডিজিটৰ মোবাইল নম্বৰ লিখক',
    'login_otp_sent_to': 'OTP পঠিওৱা হ\'ল',
    'login_otp_auto_verified': 'OTP স্বয়ংক্ৰিয়ভাৱে প্ৰমাণিত! আপোনাক লগইন কৰা হৈছে...',
    'login_enter_6_digit_otp': 'অনুগ্ৰহ কৰি ৬-ডিজিটৰ OTP লিখক',
    'login_request_otp_first': 'অনুগ্ৰহ কৰি প্ৰথমে OTP দাবি কৰক',
    'login_fill_all_fields': 'অনুগ্ৰহ কৰি সকলো ক্ষেত্ৰ পূৰণ কৰক',
    'login_invalid_email': 'অনুগ্ৰহ কৰি এটা বৈধ ইমেইল ঠিকনা লিখক',
    'login_password_too_short': 'পাছৱৰ্ড কমেও ৬টা আখৰ হ\'ব লাগিব',
    'login_enter_name': 'অনুগ্ৰহ কৰি আপোনাৰ নাম লিখক',

    // Test Series Screen (Critical #3)
    'test_series_title': 'টেষ্ট ছিৰিজ',
    'my_categories': 'মোৰ শ্ৰেণীসমূহ',
    'test_series_tab_practice': 'অনুশীলন',
    'test_series_tab_subjectwise': 'বিষয় অনুযায়ী',
    'test_series_no_tests_in_categories':
        'আপোনাৰ বাছনি কৰা শ্ৰেণীত কোনো পৰীক্ষা নাই',
    'test_series_edit_categories': 'মোৰ শ্ৰেণীসমূহ সম্পাদনা কৰক',
    'test_series_completed': 'সম্পূৰ্ণ',
    'test_series_qs_suffix': 'প্ৰশ্ন',
    'test_series_no_subjects': 'কোনো বিষয় উপলব্ধ নহয়',
    'test_series_no_subjects_in_categories':
        'আপোনাৰ বাছনি কৰা শ্ৰেণীত কোনো বিষয় নাই',
    'test_series_test_singular': 'পৰীক্ষা',
    'test_series_test_plural': 'পৰীক্ষাসমূহ',
    'test_type_mock': 'মক টেষ্ট',
    'test_type_previous_year': 'পূৰ্বৰ বছৰ',
    'test_type_daily_quiz': 'দৈনিক কুইজ',
    'test_type_practice': 'অনুশীলন',
    'test_type_subjectwise': 'বিষয় অনুযায়ী',
    'test_difficulty_easy': 'সহজ',
    'test_difficulty_medium': 'মধ্যম',
    'test_difficulty_hard': 'কঠিন',

    // Notifications Screen (Critical #5)
    'notifications_title': 'জাননীসমূহ',
    'notifications_mark_all_read': 'সকলো পঢ়া বুলি চিহ্নিত কৰক',
    'notifications_empty': 'এতিয়ালৈকে কোনো জাননী নাই',

    // Announcements Screen (Critical #6)
    'announcements_title': 'ঘোষণাসমূহ',
    'announcements_empty': 'এতিয়ালৈকে কোনো ঘোষণা নাই',
    'announcements_live_badge': 'লাইভ',
    'announcements_pinned_badge': 'পিন কৰা',
    'announcements_min_ago': 'মিনিট আগতে',
    'announcements_hour_ago': 'ঘণ্টা আগতে',
    'announcements_day_ago': 'দিন আগতে',

    // Onboarding — Category Selection Screen (Critical #7)
    'onboarding_welcome_title': 'ExamVault লৈ স্বাগতম!',
    'onboarding_welcome_desc':
        'আপুনি কোনবোৰ পৰীক্ষাৰ বাবে প্ৰস্তুতি লৈ আছে? যিমান বিচাৰে বাছক — আপোনাৰ মূল পৃষ্ঠাই এইবোৰত গুৰুত্ব দিব।',
    'onboarding_no_categories': 'এতিয়ালৈকে কোনো শ্ৰেণী উপলব্ধ নহয়।',
    'onboarding_selected': 'বাছনি কৰা',
    'onboarding_skip_for_now': 'এতিয়ালৈকে এৰক',

    // ─── Issue #19: Settings — Notifications + Logout ───
    'settings_notif_push': 'পুশ্ব জাননী',
    'settings_notif_push_subtitle': 'সকলো জাননীৰ মূল চুইচ',
    'settings_notif_announcements': 'পৰীক্ষাৰ ঘোষণা',
    'settings_notif_announcements_subtitle':
        'নতুন পৰীক্ষাৰ জাননী আৰু আপডেট',
    'settings_notif_daily_quiz': 'দৈনিক কুইজ সোঁতৱ',
    'settings_notif_daily_quiz_subtitle':
        'দৈনিক অনুশীলনৰ সোঁতৱ জাননী',
    'settings_logout': 'লগআউট',
    'settings_logout_confirm_title': 'লগআউট কৰিব নেকি?',
    'settings_logout_confirm_msg':
        'আপুনি আপোনাৰ একাউণ্টৰ পৰা চাইন আউট হ\'ব। যিকোনো সময়ত পুনৰ চাইন ইন কৰিব পাৰিব।',
    'settings_logout_confirm_button': 'লগআউট',
    'settings_cancel': 'বাতিল',

    // ─── Issue #18: PDF Viewer ───
    'pdf_opening': 'PDF খোলা হৈছে...',
    'pdf_open_failed': 'PDF খুলিব পৰা নগ\'ল',
    'pdf_no_viewer': 'এই ডিভাইচত কোনো PDF দৰ্শক এপ্ নাই।',
    'pdf_open_in_browser': 'ব্ৰাউজাৰত খোলক',
    'pdf_open_manually':
        'যদি PDF স্বয়ংক্ৰিয়ভাৱে নাখুলে, তলৰ বুটামটো টিপক।',

    // ─── Issue #20: Test History ───
    'history_title': 'পৰীক্ষাৰ ইতিহাস',
    'history_filter_all': 'সকলো',
    'history_filter_passed': 'উত্তীৰ্ণ',
    'history_filter_failed': 'অনুত্তীৰ্ণ',
    'history_empty_title': 'এতিয়ালৈকে কোনো পৰীক্ষাৰ ইতিহাস নাই',
    'history_empty_msg':
        'আপোনাৰ পৰীক্ষাৰ ফলাফল ইয়াত চাবলৈ প্ৰথম পৰীক্ষা দিয়ক।',
    'history_reattempt': 'পুনৰ চেষ্টা',
    'history_rank': 'স্থান',
    'history_accuracy': 'নিৰ্ভুলতা',
    'history_time_taken': 'সময়',
    'history_score': 'নম্বৰ',
    'history_no_results': 'এই ফিল্টাৰৰ সৈতে কোনো ফলাফল নাই।',
    'history_loading_test': 'পৰীক্ষা খোলা হৈছে…',
    'history_test_not_found':
        'পৰীক্ষা পোৱা নগ\'ল। ইয়াক আঁতৰোৱা হ\'ব পাৰে।',

    // ─── Issue #22: Invoice download ───
    'invoice_downloading': 'ইনভয়ছ ডাউনলোড হৈছে...',
    'invoice_download_success': 'ইনভয়ছ ডাউনলোড হ\'ল। খোলা হৈছে...',
    'invoice_download_failed':
        'ইনভয়ছ ডাউনলোড কৰিব পৰা নগ\'ল। সংযোগ পৰীক্ষা কৰি পুনৰ চেষ্টা কৰক।',
    'invoice_open_failed':
        'ইনভয়ছ ডাউনলোড হ\'ল কিন্তু কোনো PDF দৰ্শক উপলব্ধ নহয়। আপোনাৰ Files এপ্ৰ পৰা খোলক।',

    // ─── Issue #23: Premium current-plan + Restore ───
    'premium_current_plan': 'আপুনি প্ৰিমিয়াম সদস্য',
    'premium_current_plan_msg': '{date} লৈকে প্ৰিমিয়াম সক্ৰিয়',
    'premium_current_plan_no_expiry':
        'আপোনাৰ একাউণ্টত প্ৰিমিয়াম সক্ৰিয় আছে।',
    'premium_manage': 'সদস্যতা পৰিচালনা',
    'premium_manage_msg':
        'আপোনাৰ সদস্যতা পৰিচালনা কৰিবলৈ সমৰ্থনৰ সৈতে যোগাযোগ কৰক।',
    'premium_restore': 'ক্ৰয় পুনৰুদ্ধাৰ',
    'premium_restore_success': 'প্ৰিমিয়াম সফলভাৱে পুনৰুদ্ধাৰ হ\'ল!',
    'premium_restore_none': 'কোনো সক্ৰিয় সদস্যতা পোৱা নগ\'ল।',
    'premium_restore_loading': 'আপোনাৰ সদস্যতা পৰীক্ষা কৰা হৈছে...',

    // ─── Issue #30: Razorpay retry ───
    'contact_support': 'সমৰ্থনৰ সৈতে যোগাযোগ',
    'payment_failed_retry_msg':
        'পেমেণ্ট ব্যৰ্থ। পুনৰ চেষ্টা কৰিবলৈ Retry টিপক বা সহায়ৰ বাবে সমৰ্থনৰ সৈতে যোগাযোগ কৰক।',
  };
}
