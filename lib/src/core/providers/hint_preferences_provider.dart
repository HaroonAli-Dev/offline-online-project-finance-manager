import 'package:flutter_riverpod/legacy.dart';

final hintPreferencesProvider =
    StateNotifierProvider<PageGuideVisibilityNotifier, Map<String, bool>>((
      ref,
    ) {
      return PageGuideVisibilityNotifier();
    });

class PageGuideVisibilityNotifier extends StateNotifier<Map<String, bool>> {
  // Default state: hint is hidden (false = hidden), button is green.
  // When user clicks the green button, hint becomes visible (true).
  PageGuideVisibilityNotifier() : super({});

  /// Returns true when the hint panel is open/visible.
  bool isVisible(String pageKey) => state[pageKey] ?? false;

  /// Returns true when the hint panel is hidden (default on every launch).
  bool isDismissed(String pageKey) => !isVisible(pageKey);

  void setVisible(String pageKey, bool visible) {
    state = {...state, pageKey: visible};
  }

  Future<void> setDismissed(String pageKey, bool dismissed) async {
    setVisible(pageKey, !dismissed);
  }

  Future<void> toggleHint(String pageKey) async {
    setVisible(pageKey, !isVisible(pageKey));
  }

  void clearAll() {
    state = {};
  }
}

class HintPreferencesNotifier extends PageGuideVisibilityNotifier {
  HintPreferencesNotifier() : super();
}
