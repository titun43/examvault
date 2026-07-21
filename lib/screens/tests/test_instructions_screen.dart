// =============================================================================
// ExamVault - Test Instructions Screen (Agree & Continue)
// =============================================================================
// Shown BEFORE TakeTestScreen so the user reads the rules while the clock
// is NOT running — the timer only starts once they tap "Agree & Start Test"
// here, which then pushReplacement's into TakeTestScreen. Previously "Start
// Test" jumped straight into the timed test with no instructions step at
// all, so time was ticking while a first-time user figured out the UI.
//
// Drop-in replacement for TakeTestScreen at every call site: same
// constructor shape (test, categoryId), so navigation call sites just swap
// the widget being pushed.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/test_model.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
import 'take_test_screen.dart';
import '../../l10n/app_localizations.dart';

class TestInstructionsScreen extends StatefulWidget {
  final TestModel test;
  final String? categoryId;

  const TestInstructionsScreen({super.key, required this.test, this.categoryId});

  @override
  State<TestInstructionsScreen> createState() => _TestInstructionsScreenState();
}

class _TestInstructionsScreenState extends State<TestInstructionsScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final test = widget.test;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final marksPerQuestion = test.questionCount > 0
        ? (test.totalMarks / test.questionCount)
        : 0.0;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(tr(context, 'instr_title')),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                children: [
                  // ===== Summary header card =====
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spaceXl),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppTheme.brandGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      boxShadow: AppTheme.softShadow1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          test.title,
                          style: AppFonts.style(
                            size: 20,
                            weight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLg),
                        Row(
                          children: [
                            _headerStat(
                                Icons.help_outline_rounded, '${test.questionCount}', tr(context, 'instr_questions')),
                            _headerStatDivider(),
                            _headerStat(
                                Icons.timer_outlined, '${test.duration}', tr(context, 'instr_minutes')),
                            _headerStatDivider(),
                            _headerStat(
                                Icons.star_outline_rounded, '${test.totalMarks}', tr(context, 'instr_marks')),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),

                  const SizedBox(height: AppTheme.spaceLg),

                  // ===== Marking scheme =====
                  _sectionCard(
                    isDark: isDark,
                    title: tr(context, 'instr_markingScheme'),
                    icon: Icons.rule_rounded,
                    iconColor: AppTheme.primaryColor,
                    children: [
                      _markingRow(
                        icon: Icons.add_circle_outline,
                        color: AppTheme.successColor,
                        label: tr(context, 'instr_correctAnswer'),
                        value: '+ ${_fmt(marksPerQuestion)} marks',
                        isDark: isDark,
                      ),
                      if (test.negativeMarking) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        _markingRow(
                          icon: Icons.remove_circle_outline,
                          color: AppTheme.errorColor,
                          label: tr(context, 'instr_wrongAnswer'),
                          value: '- ${_fmt(test.negativeMarks)} marks',
                          isDark: isDark,
                        ),
                      ],
                      const SizedBox(height: AppTheme.spaceSm),
                      _markingRow(
                        icon: Icons.radio_button_unchecked,
                        color: Colors.grey,
                        label: tr(context, 'instr_notAttempted'),
                        value: tr(context, 'instr_zeroMarks'),
                        isDark: isDark,
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.06),

                  const SizedBox(height: AppTheme.spaceLg),

                  // ===== Question palette legend =====
                  _sectionCard(
                    isDark: isDark,
                    title: tr(context, 'instr_questionPalette'),
                    icon: Icons.grid_view_rounded,
                    iconColor: AppTheme.accentColor,
                    children: [
                      Wrap(
                        spacing: AppTheme.spaceLg,
                        runSpacing: AppTheme.spaceSm,
                        children: [
                          _paletteLegend(AppTheme.successColor, tr(context, 'test_answered'), isDark),
                          _paletteLegend(AppTheme.errorColor, tr(context, 'test_notAnswered'), isDark),
                          _paletteLegend(
                              isDark ? Colors.white24 : Colors.grey.shade400,
                              tr(context, 'test_notVisited'), isDark),
                          _paletteLegend(Colors.purple, tr(context, 'test_markReview'), isDark),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(delay: 150.ms, duration: 350.ms).slideY(begin: 0.06),

                  const SizedBox(height: AppTheme.spaceLg),

                  // ===== General instructions =====
                  _sectionCard(
                    isDark: isDark,
                    title: tr(context, 'instr_generalInstructions'),
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.blue,
                    children: [
                      _instructionItem(
                        Icons.timer_outlined,
                        tr(context, 'instr_timerWarning'),
                        isDark,
                      ),
                      _instructionItem(
                        Icons.touch_app_outlined,
                        tr(context, 'instr_tapOption'),
                        isDark,
                      ),
                      _instructionItem(
                        Icons.swap_horiz_rounded,
                        tr(context, 'instr_navigate'),
                        isDark,
                      ),
                      _instructionItem(
                        Icons.wifi_off_rounded,
                        tr(context, 'instr_internet'),
                        isDark,
                      ),
                      if (test.instructions != null &&
                          test.instructions!.trim().isNotEmpty)
                        _instructionItem(
                          Icons.notes_rounded,
                          test.instructions!.trim(),
                          isDark,
                        ),
                    ],
                  ).animate().fadeIn(delay: 200.ms, duration: 350.ms).slideY(begin: 0.06),

                  const SizedBox(height: AppTheme.spaceXl),
                ],
              ),
            ),

            // ===== Sticky footer: agree checkbox + start button =====
            Container(
              padding: EdgeInsets.fromLTRB(
                AppTheme.spaceLg,
                AppTheme.spaceMd,
                AppTheme.spaceLg,
                AppTheme.spaceMd + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardColor : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => setState(() => _agreed = !_agreed),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _agreed,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (v) => setState(() => _agreed = v ?? false),
                          ),
                          Expanded(
                            child: Text(
                              tr(context, 'instr_agree'),
                              style: AppFonts.style(
                                size: 13,
                                weight: FontWeight.w500,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      onPressed: _agreed
                          ? () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => TakeTestScreen(
                                    test: widget.test,
                                    categoryId: widget.categoryId,
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        tr(context, 'instr_agreeStart'),
                        style: AppFonts.style(size: 16, weight: FontWeight.w700),
                      ),
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

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  Widget _headerStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: AppFonts.style(size: 16, weight: FontWeight.w800, color: Colors.white)),
          Text(label,
              style: AppFonts.style(
                  size: 11, weight: FontWeight.w500, color: Colors.white.withOpacity(0.85))),
        ],
      ),
    );
  }

  Widget _headerStatDivider() {
    return Container(width: 1, height: 36, color: Colors.white.withOpacity(0.25));
  }

  Widget _sectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: AppTheme.softShadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Text(
                title,
                style: AppFonts.style(
                  size: 15,
                  weight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          ...children,
        ],
      ),
    );
  }

  Widget _markingRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              label,
              style: AppFonts.style(
                size: 13,
                weight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: AppFonts.style(size: 13, weight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _paletteLegend(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppFonts.style(
            size: 12,
            weight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
          ),
        ),
      ],
    );
  }

  Widget _instructionItem(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45)),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              text,
              style: AppFonts.style(
                size: 13,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
