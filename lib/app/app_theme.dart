import 'package:flutter/material.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF74639B),
    brightness: brightness,
    primary: dark ? const Color(0xFFC8B7EA) : const Color(0xFF69548E),
    surface: dark ? const Color(0xFF222330) : Colors.white,
    onSurface: dark ? const Color(0xFFF1EDF7) : const Color(0xFF303446),
    primaryContainer: dark ? const Color(0xFF3B3151) : const Color(0xFFEAE5FA),
    onPrimaryContainer: dark
        ? const Color(0xFFEAE5FA)
        : const Color(0xFF382953),
    secondaryContainer: dark
        ? const Color(0xFF253E38)
        : const Color(0xFFDFF2E8),
    onSecondaryContainer: dark
        ? const Color(0xFFDFF2E8)
        : const Color(0xFF23483A),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Segoe UI',
    scaffoldBackgroundColor: dark
        ? const Color(0xFF191A24)
        : const Color(0xFFF7F8FC),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.15),
      selectedIconTheme: IconThemeData(color: scheme.primary),
    ),
    appBarTheme: AppBarTheme(backgroundColor: scheme.surface),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.4),
    ),
  );
}
