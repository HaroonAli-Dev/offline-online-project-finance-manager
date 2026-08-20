import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

final hintPreferencesProvider =
    StateNotifierProvider<HintPreferencesNotifier, Map<String, bool>>((ref) {
      return HintPreferencesNotifier();
    });

class HintPreferencesNotifier extends StateNotifier<Map<String, bool>> {
  HintPreferencesNotifier() : super({}) {
    _loadPreferences();
  }

  static const String _keyPrefix = 'hint_dismissed_';

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    final Map<String, bool> loaded = {};
    for (final fullKey in keys) {
      final pageKey = fullKey.substring(_keyPrefix.length);
      loaded[pageKey] = prefs.getBool(fullKey) ?? false;
    }
    state = loaded;
  }

  bool isDismissed(String pageKey) {
    return state[pageKey] ?? false;
  }

  Future<void> setDismissed(String pageKey, bool dismissed) async {
    state = {...state, pageKey: dismissed};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$pageKey', dismissed);
  }

  Future<void> toggleHint(String pageKey) async {
    final current = isDismissed(pageKey);
    await setDismissed(pageKey, !current);
  }
}
