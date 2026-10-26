import 'package:flutter/material.dart';

abstract final class AppColors {
  static const darkBackground = Color(0xFF0C1B2A);
  static const darkSurface = Color(0xFF12263A);
  static const darkSurfaceHigh = Color(0xFF1A3350);
  static const darkBorder = Color(0xFF24405C);
  static const darkPrimary = Color(0xFF00FF87);
  static const darkOnPrimary = Color(0xFF04140D);
  static const darkText = Color(0xFFFFFFFF);
  static const darkMuted = Color(0xFF9FB3C8);
  static const darkError = Color(0xFFFF5C6C);
  static const darkWarning = Color(0xFFFFB84D);

  static const lightBackground = Color(0xFFF4F8FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF0C1B2A);
  static const lightMuted = Color(0xFF52667A);
  // Darkened slightly from the requested sample so white button text meets AA.
  static const lightPrimary = Color(0xFF008040);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFD5E0EA);
  static const lightError = Color(0xFFB42336);
  static const lightWarning = Color(0xFF8A4B00);

  static const successDark = darkPrimary;
  static const successLight = lightPrimary;
  static const infoDark = Color(0xFF85C9FF);
  static const infoLight = Color(0xFF075B96);
}

abstract final class AppTheme {
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceHigh = isDark ? AppColors.darkSurfaceHigh : AppColors.lightSurface;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final onPrimary = isDark ? AppColors.darkOnPrimary : AppColors.lightOnPrimary;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final error = isDark ? AppColors.darkError : AppColors.lightError;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
      primary: primary,
      onPrimary: onPrimary,
      secondary: primary,
      onSecondary: onPrimary,
      error: error,
      onError: isDark ? AppColors.darkOnPrimary : Colors.white,
    ).copyWith(
      onSurface: text,
      onSurfaceVariant: muted,
      outline: border,
      outlineVariant: border,
      surfaceContainerHighest: surfaceHigh,
      primaryContainer: isDark ? const Color(0xFF123A2D) : const Color(0xFFD9F4E5),
      onPrimaryContainer: isDark ? AppColors.darkPrimary : const Color(0xFF00552B),
      errorContainer: isDark ? const Color(0xFF4A2028) : const Color(0xFFFFE8EB),
      onErrorContainer: isDark ? const Color(0xFFFFB6BE) : const Color(0xFF7D1728),
      inverseSurface: isDark ? AppColors.lightText : AppColors.darkSurface,
      onInverseSurface: isDark ? AppColors.lightSurface : AppColors.darkText,
      inversePrimary: isDark ? AppColors.lightPrimary : AppColors.darkPrimary,
    );
    final textTheme = TextTheme(
      displayLarge: TextStyle(fontSize: 48, height: 1.08, fontWeight: FontWeight.w700, color: text, letterSpacing: -1.2),
      displayMedium: TextStyle(fontSize: 38, height: 1.12, fontWeight: FontWeight.w700, color: text, letterSpacing: -0.6),
      displaySmall: TextStyle(fontSize: 32, height: 1.2, fontWeight: FontWeight.w700, color: text),
      headlineLarge: TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w700, color: text),
      headlineMedium: TextStyle(fontSize: 26, height: 1.25, fontWeight: FontWeight.w700, color: text),
      headlineSmall: TextStyle(fontSize: 22, height: 1.3, fontWeight: FontWeight.w600, color: text),
      titleLarge: TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w600, color: text),
      titleMedium: TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w600, color: text),
      titleSmall: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: text),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: text),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: text),
      bodySmall: TextStyle(fontSize: 12, height: 1.45, color: muted),
      labelLarge: TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600, color: text),
      labelMedium: TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600, color: muted),
      labelSmall: TextStyle(fontSize: 11, height: 1.3, fontWeight: FontWeight.w600, color: muted),
    );
    final roundedButton = WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: _NoTransitionsBuilder()}),
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, foregroundColor: text, surfaceTintColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, titleTextStyle: textTheme.titleLarge),
      cardTheme: CardThemeData(color: surface, surfaceTintColor: Colors.transparent, elevation: 0, margin: const EdgeInsets.symmetric(vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: border.withValues(alpha: 0.65)))),
      filledButtonTheme: FilledButtonThemeData(style: ButtonStyle(minimumSize: const WidgetStatePropertyAll(Size(64, 52)), padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 22, vertical: 14)), shape: roundedButton, backgroundColor: WidgetStatePropertyAll(primary), foregroundColor: WidgetStatePropertyAll(onPrimary), textStyle: WidgetStatePropertyAll(textTheme.labelLarge))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(minimumSize: const WidgetStatePropertyAll(Size(64, 52)), padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 14)), shape: roundedButton, foregroundColor: WidgetStatePropertyAll(primary), side: WidgetStatePropertyAll(BorderSide(color: primary, width: 1.5)), textStyle: WidgetStatePropertyAll(textTheme.labelLarge))),
      textButtonTheme: TextButtonThemeData(style: ButtonStyle(minimumSize: const WidgetStatePropertyAll(Size(48, 48)), foregroundColor: WidgetStatePropertyAll(primary), textStyle: WidgetStatePropertyAll(textTheme.labelLarge))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: surface, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17), labelStyle: TextStyle(color: muted), hintStyle: TextStyle(color: muted), errorStyle: TextStyle(color: error), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primary, width: 2)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: error)), focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: error, width: 2))),
      chipTheme: ChipThemeData(backgroundColor: surface, selectedColor: primary.withValues(alpha: 0.16), disabledColor: surfaceHigh, labelStyle: TextStyle(color: text), secondaryLabelStyle: TextStyle(color: primary, fontWeight: FontWeight.w600), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), side: WidgetStateBorderSide.resolveWith((states) => BorderSide(color: states.contains(WidgetState.selected) ? primary : border, width: states.contains(WidgetState.selected) ? 1.5 : 1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), showCheckmark: false),
      dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, titleTextStyle: textTheme.titleLarge, contentTextStyle: textTheme.bodyMedium, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      snackBarTheme: SnackBarThemeData(backgroundColor: surfaceHigh, contentTextStyle: TextStyle(color: text), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      listTileTheme: ListTileThemeData(textColor: text, iconColor: muted, tileColor: Colors.transparent, minVerticalPadding: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      switchTheme: SwitchThemeData(thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? onPrimary : muted), trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primary : border), trackOutlineColor: WidgetStatePropertyAll(border)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary, linearTrackColor: primary.withValues(alpha: 0.18), circularTrackColor: primary.withValues(alpha: 0.18)),
      dividerColor: border,
    );
  }
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(Route<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => child;
}

