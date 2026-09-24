import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    colorScheme: const ColorScheme.light(
      primary: MainScreenColors.youtubeRed,
      onPrimary: Colors.white,
      secondary: MainScreenColors.lightSecondaryPink,
      onSecondary: Colors.white,
      surface: MainScreenColors.lightSurfaceColor,
      onSurface: MainScreenColors.lightTextColor,
      onSurfaceVariant: MainScreenColors.lightSecondaryTextColor,
      outline: MainScreenColors.lightDividerColor,
      outlineVariant: MainScreenColors.lightDividerColor,
    ),
    primaryColor: MainScreenColors.youtubeRed,
    scaffoldBackgroundColor: MainScreenColors.lightBackgroundColor,
    dividerColor: MainScreenColors.lightDividerColor,
    dividerTheme: const DividerThemeData(
      color: MainScreenColors.lightDividerColor,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MainScreenColors.lightSurfaceColor,
      foregroundColor: MainScreenColors.lightTextColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: MainScreenColors.lightTextColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: MainScreenColors.lightTextColor),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: MainScreenColors.lightSurfaceColor,
      selectedItemColor: MainScreenColors.youtubeRed,
      unselectedItemColor: MainScreenColors.lightSecondaryTextColor,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: MainScreenColors.lightSurfaceColor,
      indicatorColor: MainScreenColors.youtubeRed.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MainScreenColors.youtubeRed,
          );
        }
        return const TextStyle(
          fontSize: 12,
          color: MainScreenColors.lightSecondaryTextColor,
        );
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: MainScreenColors.lightElevatedSurface,
      selectedColor: MainScreenColors.youtubeRed.withValues(alpha: 0.2),
      labelStyle: const TextStyle(color: MainScreenColors.lightTextColor),
      secondaryLabelStyle: const TextStyle(
        color: MainScreenColors.lightSecondaryTextColor,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: MainScreenColors.lightTextColor),
      bodyMedium: TextStyle(color: MainScreenColors.lightTextColor),
      bodySmall: TextStyle(color: MainScreenColors.lightSecondaryTextColor),
      titleLarge: TextStyle(color: MainScreenColors.lightTextColor),
      titleMedium: TextStyle(color: MainScreenColors.lightTextColor),
      titleSmall: TextStyle(color: MainScreenColors.lightSecondaryTextColor),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    colorScheme: const ColorScheme.dark(
      primary: MainScreenColors.youtubeRed,
      onPrimary: Colors.white,
      secondary: MainScreenColors.darkSecondaryPink,
      onSecondary: Colors.white,
      surface: MainScreenColors.darkSurfaceColor,
      onSurface: MainScreenColors.darkTextColor,
      onSurfaceVariant: MainScreenColors.darkSecondaryTextColor,
      outline: MainScreenColors.darkDividerColor,
      outlineVariant: MainScreenColors.darkDividerColor,
      surfaceContainerHighest: MainScreenColors.darkElevatedSurface,
    ),
    primaryColor: MainScreenColors.youtubeRed,
    scaffoldBackgroundColor: MainScreenColors.darkBackgroundColor,
    dividerColor: MainScreenColors.darkDividerColor,
    dividerTheme: const DividerThemeData(
      color: MainScreenColors.darkDividerColor,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MainScreenColors.darkBackgroundColor,
      foregroundColor: MainScreenColors.darkTextColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: MainScreenColors.darkTextColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: MainScreenColors.darkTextColor),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: MainScreenColors.darkSurfaceColor,
      selectedItemColor: MainScreenColors.youtubeRed,
      unselectedItemColor: MainScreenColors.darkSecondaryTextColor,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: MainScreenColors.darkSurfaceColor,
      indicatorColor: MainScreenColors.youtubeRed.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MainScreenColors.youtubeRed,
          );
        }
        return const TextStyle(
          fontSize: 12,
          color: MainScreenColors.darkSecondaryTextColor,
        );
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: MainScreenColors.darkElevatedSurface,
      selectedColor: MainScreenColors.youtubeRed.withValues(alpha: 0.25),
      labelStyle: const TextStyle(color: MainScreenColors.darkTextColor),
      secondaryLabelStyle: const TextStyle(
        color: MainScreenColors.darkSecondaryTextColor,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: MainScreenColors.darkTextColor),
      bodyMedium: TextStyle(color: MainScreenColors.darkTextColor),
      bodySmall: TextStyle(color: MainScreenColors.darkSecondaryTextColor),
      titleLarge: TextStyle(color: MainScreenColors.darkTextColor),
      titleMedium: TextStyle(color: MainScreenColors.darkTextColor),
      titleSmall: TextStyle(color: MainScreenColors.darkSecondaryTextColor),
    ),
  );
}

class FadeForwardsPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeForwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}
