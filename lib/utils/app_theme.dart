// lib/utils/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runtime-switchable theme. Widgets read the [AppTheme] color getters, and
/// [ThemeController] notifies the root to rebuild everything in the other
/// palette. NOTE: because the colors are getters, constructors that use them
/// must not be `const` (enforced by tool/deconst_theme.dart).
class AppTheme {
  static bool isDark = true;

  // ── Brand (same in both themes) ──
  static const Color green     = Color(0xFF1D9E75);
  static const Color greenDim  = Color(0xFF0d2a1f);
  static const Color amber     = Color(0xFFBA7517);
  static const Color amberDim  = Color(0xFF1a1a0a);
  static const Color red       = Color(0xFFE24B4A);
  static const Color blue      = Color(0xFF185FA5);

  // ── Surface ──
  static Color get bg        => isDark ? const Color(0xFF0d0d0d) : const Color(0xFFEDF2F9);
  static Color get surface   => isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);
  static Color get card      => isDark ? const Color(0xFF1a1a1a) : const Color(0xFFF6F9FC);
  static Color get border    => isDark ? const Color(0xFF242424) : const Color(0xFFD7E1EE);
  static Color get divider   => isDark ? const Color(0xFF1e1e1e) : const Color(0xFFE2E9F3);

  // ── Text ──
  static Color get textPrimary   => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF142433);
  static Color get textSecondary => isDark ? const Color(0xFF888888) : const Color(0xFF52657A);
  static Color get textMuted     => isDark ? const Color(0xFF444444) : const Color(0xFF8FA0B3);

  // ── Route colours ──
  static const Map<String, Color> routeColors = {
    '38Y' : Color(0xFF1D9E75),
    '400Y': Color(0xFF185FA5),
    '28C' : Color(0xFFBA7517),
    '900' : Color(0xFF993556),
    '99'  : Color(0xFF534AB7),
    '222' : Color(0xFF0F6E56),
    '5K'  : Color(0xFFD85A30),
  };

  static Color routeColor(String n) =>
      routeColors[n] ?? const Color(0xFF185FA5);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.dark(
      primary: green,
      secondary: blue,
      surface: surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w600,
        color: textPrimary, letterSpacing: -0.3,
      ),
    ),
    dividerColor: divider,
    cardColor: card,
  );

  /// The classic white & blue look.
  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.light(
      primary: green,
      secondary: blue,
      surface: surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w600,
        color: textPrimary, letterSpacing: -0.3,
      ),
    ),
    dividerColor: divider,
    cardColor: card,
  );

  static ThemeData get current => isDark ? dark : light;
}

/// Loads/persists the choice and rebuilds the app when it changes.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'app_theme_dark';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    AppTheme.isDark = prefs.getBool(_prefsKey) ?? true;
    _applySystemChrome();
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (AppTheme.isDark == value) return;
    AppTheme.isDark = value;
    _applySystemChrome();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (e) {
      debugPrint('ThemeController: persist failed: $e');
    }
  }

  void toggle() => setDark(!AppTheme.isDark);

  void _applySystemChrome() {
    SystemChrome.setSystemUIOverlayStyle(
      AppTheme.isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent),
    );
  }
}
