import 'package:flutter_riverpod/legacy.dart';

final hintPreferencesProvider =
    StateNotifierProvider<PageGuideVisibilityNotifier, Map<String, bool>>((
      ref,
    ) {
      return PageGuideVisibilityNotifier();
    });

class PageGuideVisibilityNotifier extends StateNotifier<Map<String, bool>> {
  PageGuideVisibilityNotifier() : super({});

  bool isVisible(String pageKey) {
    return state[pageKey] ?? false;
  }

  bool isDismissed(String pageKey) {
    return !isVisible(pageKey);
  }

  void setVisible(String pageKey, bool visible) {
    final nextState = <String, bool>{...state};
    if (visible) {
      nextState[pageKey] = true;
    } else {
      nextState.remove(pageKey);
    }
    state = nextState;
  }

  Future<void> setDismissed(String pageKey, bool dismissed) async {
    setVisible(pageKey, !dismissed);
  }

  void toggleGuideVisible(String pageKey) {
    setVisible(pageKey, !isVisible(pageKey));
  }

  Future<void> toggleHint(String pageKey) async {
    toggleGuideVisible(pageKey);
  }

  void clearAll() {
    state = {};
  }
}

class HintPreferencesNotifier extends PageGuideVisibilityNotifier {
  HintPreferencesNotifier() : super();
}
