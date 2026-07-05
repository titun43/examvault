// =============================================================================
// ExamVault - Action Button Model
// A reusable config for a single CTA button on a Banner or Announcement.
// A banner/announcement can have up to two of these (primary + secondary),
// each independently configured by the admin.
//
// An ActionButton is either:
//   - external : opens a URL in the browser (apply form, official site, PDF…)
//   - inApp    : navigates to a screen INSIDE the app (test series, a specific
//                test, a category, daily quiz, leaderboard, etc.)
//
// The in-app destination is identified by [screen] (a string enum) and an
// optional [params] map (e.g. {'testId': 'xxx'} or {'categoryId': 'yyy'}).
// See lib/utils/in_app_navigator.dart for the full list of supported screens.
//
// Backward compatibility: older banners/announcements only had a single
// `link` + `linkLabel` field. Those are treated as a primary external button
// when no explicit primaryButton is set (see the model fromFirestore logic).
// =============================================================================

enum ActionType { external, inApp }

class ActionButton {
  final String label;
  final ActionType type;

  /// For [ActionType.external] — the URL to open.
  final String? url;

  /// For [ActionType.inApp] — the destination screen identifier.
  /// Supported values: testSeries, dailyQuiz, upcomingExams, currentAffairs,
  /// announcements, leaderboard, premium, category, subject, test.
  final String? screen;

  /// For [ActionType.inApp] — parameters for the destination screen
  /// (e.g. {'testId': 'abc'}, {'categoryId': 'xyz'}).
  final Map<String, dynamic> params;

  const ActionButton({
    required this.label,
    required this.type,
    this.url,
    this.screen,
    this.params = const {},
  });

  /// Returns true if the button is fully configured and can be rendered /
  /// acted on. A button with an empty label is considered not set.
  bool get isSet => label.trim().isNotEmpty;

  /// Returns true if this is an in-app button whose target screen + params
  /// are valid enough to navigate to.
  bool get isNavigable =>
      type == ActionType.inApp &&
      screen != null &&
      screen!.isNotEmpty;

  factory ActionButton.fromMap(Map<String, dynamic> data) {
    final rawType = data['type']?.toString() ?? 'external';
    return ActionButton(
      label: (data['label'] ?? '').toString(),
      type: rawType == 'inApp' ? ActionType.inApp : ActionType.external,
      url: data['url']?.toString(),
      screen: data['screen']?.toString(),
      params: data['params'] is Map
          ? Map<String, dynamic>.from(data['params'] as Map)
          : const {},
    );
  }

  /// Parses a dynamic value that may be a Map (new format) or null. Returns
  /// null when the value is null or the resulting button has no label.
  static ActionButton? fromDynamic(dynamic v) {
    if (v == null) return null;
    if (v is! Map) return null;
    final btn = ActionButton.fromMap(Map<String, dynamic>.from(v));
    return btn.isSet ? btn : null;
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'type': type == ActionType.inApp ? 'inApp' : 'external',
      'url': url,
      'screen': screen,
      'params': params,
    };
  }

  ActionButton copyWith({
    String? label,
    ActionType? type,
    String? url,
    String? screen,
    Map<String, dynamic>? params,
  }) {
    return ActionButton(
      label: label ?? this.label,
      type: type ?? this.type,
      url: url ?? this.url,
      screen: screen ?? this.screen,
      params: params ?? this.params,
    );
  }
}
