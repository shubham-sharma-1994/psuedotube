import 'package:flutter/material.dart';

class MainScreenColors {
  // Legacy / accent defaults (kept for Settings accent picker)
  static const primaryPurple = Color(0xFF6C63FF);
  static const secondaryPink = Color(0xFFFF63B8);
  static const skyBlue = Color(0xFF63B8FF);
  static const youtubeRed = Color(0xFFFF0033); // YTM-inspired primary accent
  static const backgroundColor = Color(0xFF000000);
  static const textColor = Color(0xFFFFFFFF);

  // ── Dark mode (YouTube Music aligned) ─────────────────────────────────────
  static const darkPrimaryPurple = Color(0xFF6C63FF);
  static const darkSecondaryPink = Color(0xFFFF63B8);
  /// True black scaffold — matches YT Music dark mode
  static const darkBackgroundColor = Color(0xFF000000);
  /// Primary surface (cards, nav bar, mini player)
  static const darkSurfaceColor = Color(0xFF121212);
  /// Elevated surface (sheets, menus, chips background)
  static const darkElevatedSurface = Color(0xFF212121);
  static const darkTextColor = Color(0xFFFFFFFF);
  /// Secondary / muted text (artists, timestamps)
  static const darkSecondaryTextColor = Color(0xFFAAAAAA);
  /// Dividers and subtle borders
  static const darkDividerColor = Color(0xFF2A2A2A);
  static const surfaceColor = Color(0xFF121212);
  static const darkTirtiaryColor = Color(0xFF63FF6C);

  // ── Light mode (unchanged intent, slightly cleaner neutrals) ──────────────
  static const lightPrimaryPurple = Color(0xFF6C63FF);
  static const lightSecondaryPink = Color(0xFFFF63B8);
  static const lightBackgroundColor = Color(0xFFF5F5F5);
  static const lightSurfaceColor = Color(0xFFFFFFFF);
  static const lightElevatedSurface = Color(0xFFF0F0F0);
  static const lightTextColor = Color(0xFF000000);
  static const lightSecondaryTextColor = Color(0xFF666666);
  static const lightDividerColor = Color(0xFFE0E0E0);
  static const lightTirtiaryColor = Color(0xFF63FF6C);

  static const List<Color> accentColors = [
    youtubeRed,
    secondaryPink,
    skyBlue,
    Color(0xFFFF6363),
    Color(0xFF6C63FF),
    Color(0xFFB863FF),
    Color(0xFFFF63FF),
    Color(0xFFB8860B),
    Color(0xFF3F51B5),
    Color(0xFFFF7F50),
    Color(0xFF808000),
  ];

  static Color getPrimaryColor(bool isDarkMode) =>
      isDarkMode ? darkPrimaryPurple : lightPrimaryPurple;

  static Color getSecondaryColor(bool isDarkMode) =>
      isDarkMode ? darkSecondaryPink : lightSecondaryPink;

  static Color getTirtiaryColor(bool isDarkMode) =>
      isDarkMode ? darkTirtiaryColor : lightTirtiaryColor;

  static Color getBackgroundColor(bool isDarkMode) =>
      isDarkMode ? darkBackgroundColor : lightBackgroundColor;

  static Color getSurfaceColor(bool isDarkMode) =>
      isDarkMode ? darkSurfaceColor : lightSurfaceColor;

  static Color getElevatedSurfaceColor(bool isDarkMode) =>
      isDarkMode ? darkElevatedSurface : lightElevatedSurface;

  static Color getTextColor(bool isDarkMode) =>
      isDarkMode ? darkTextColor : lightTextColor;

  static Color getSecondaryTextColor(bool isDarkMode) =>
      isDarkMode ? darkSecondaryTextColor : lightSecondaryTextColor;

  static Color getDividerColor(bool isDarkMode) =>
      isDarkMode ? darkDividerColor : lightDividerColor;
}
