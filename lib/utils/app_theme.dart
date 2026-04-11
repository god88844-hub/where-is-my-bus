// lib/utils/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Brand ──
  static const Color green     = Color(0xFF1D9E75);
  static const Color greenDim  = Color(0xFF0d2a1f);
  static const Color amber     = Color(0xFFBA7517);
  static const Color amberDim  = Color(0xFF1a1a0a);
  static const Color red       = Color(0xFFE24B4A);
  static const Color blue      = Color(0xFF185FA5);

  // ── Surface ──
  static const Color bg        = Color(0xFF0d0d0d);
  static const Color surface   = Color(0xFF141414);
  static const Color card      = Color(0xFF1a1a1a);
  static const Color border    = Color(0xFF242424);
  static const Color divider   = Color(0xFF1e1e1e);

  // ── Text ──
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted     = Color(0xFF444444);

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
    colorScheme: const ColorScheme.dark(
      primary: green,
      secondary: blue,
      surface: surface,
      background: bg,
    ),
    appBarTheme: const AppBarTheme(
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
}
