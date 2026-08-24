import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide language toggle (English / Telugu).
///
/// The conductor audience includes elderly drivers who read Telugu more
/// comfortably, so every primary surface reads its labels through
/// [t] and re-renders when the language flips.
class AppLanguage extends ChangeNotifier {
  AppLanguage._();

  static final AppLanguage instance = AppLanguage._();

  static const _prefsKey = 'app_language_telugu';

  bool _isTelugu = false;
  bool _loaded = false;

  bool get isTelugu => _isTelugu;

  /// Picks the Telugu or English string based on the current language.
  String t(String english, String telugu) => _isTelugu ? telugu : english;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isTelugu = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      _isTelugu = false;
    }
  }

  Future<void> setTelugu(bool value) async {
    if (_isTelugu == value) return;
    _isTelugu = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // persistence is best-effort; the toggle still works this session
    }
  }
}
