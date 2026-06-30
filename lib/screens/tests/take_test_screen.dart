// =============================================================================
// ExamVault - Take Test Screen (Test taking with timer)
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/test_model.dart';
import '../../models/question_model.dart';
import '../../models/test_result_model.dart';
import '../../services/firestore_service.dart';
import '../../services/admob_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'result_screen.dart';

class TakeTestScreen extends StatefulWidget {
  final TestModel test;

  const TakeTestScreen({super.key, required this.test});

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
  bool _showSubmitDialog = false;
  bool _isSubmitting = false; // guards against double-submission

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _timeRemaining = widget.test.duration * 60;
    _startTimer();
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
    // Firestore/AdMob error never crashes the app after submission (which was
    // the "app auto-closes after taking a test" bug). We navigate to the
    // result screen regardless — the user already finished the test and
    // deserves to see their score.
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

    // 4) Show interstitial ad (best-effort — never crash if ad not ready).
    try {
      await AdMobService.showInterstitialAd();
    } catch (e) {
      print('showInterstitialAd error (non-fatal): $e');
    }

    // 5) Navigate to result screen. Use pushReplacement so the test screen is
    //    popped off the stack (prevents "back" returning to a finished test).
    if (!mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
              backgroundColor: Colors.grey.shade200,
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Marks: ${question.marks}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
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
                                    : Colors.grey.shade300,
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
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + index),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade700,
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
                                          : Colors.black87,
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
                              : Colors.grey.shade200,
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
                                  : Colors.grey.shade700,
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
