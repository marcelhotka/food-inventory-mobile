import 'package:flutter/material.dart';

import 'safo_tokens.dart';

abstract final class SafoTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: SafoColors.primary,
      onPrimary: Colors.white,
      secondary: SafoColors.danger,
      onSecondary: Colors.white,
      error: SafoColors.danger,
      onError: Colors.white,
      surface: SafoColors.surface,
      onSurface: SafoColors.textPrimary,
    );

    const textTheme = TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: SafoColors.textPrimary,
        height: 1.1,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: SafoColors.textPrimary,
        height: 1.15,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: SafoColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: SafoColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: SafoColors.textPrimary,
        height: 1.35,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: SafoColors.textPrimary,
        height: 1.35,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: SafoColors.textSecondary,
        height: 1.3,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: SafoColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: SafoColors.textSecondary,
      ),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: SafoColors.background,
      canvasColor: SafoColors.background,
      textTheme: textTheme,
      dividerColor: SafoColors.border,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: SafoColors.background,
        foregroundColor: SafoColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: SafoColors.textPrimary,
          height: 1.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: SafoColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SafoRadii.xl),
          side: const BorderSide(color: SafoColors.border),
        ),
      ),
      iconTheme: const IconThemeData(color: SafoColors.textPrimary),
      dividerTheme: const DividerThemeData(
        color: SafoColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SafoColors.surface,
        selectedColor: SafoColors.primary,
        disabledColor: SafoColors.surfaceSoft,
        secondarySelectedColor: SafoColors.primarySoft,
        padding: const EdgeInsets.symmetric(
          horizontal: SafoSpacing.sm,
          vertical: SafoSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SafoRadii.pill),
          side: const BorderSide(color: SafoColors.border),
        ),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: SafoColors.textSecondary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        brightness: Brightness.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SafoColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SafoSpacing.md,
          vertical: SafoSpacing.md,
        ),
        hintStyle: const TextStyle(
          color: SafoColors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: SafoColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SafoRadii.pill),
          borderSide: const BorderSide(color: SafoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SafoRadii.pill),
          borderSide: const BorderSide(color: SafoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SafoRadii.pill),
          borderSide: const BorderSide(color: SafoColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SafoRadii.pill),
          borderSide: const BorderSide(color: SafoColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SafoRadii.pill),
          borderSide: const BorderSide(color: SafoColors.danger, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SafoColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: SafoColors.primarySoft,
        height: 72,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? SafoColors.primary : SafoColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? SafoColors.primary : SafoColors.textMuted,
            size: 24,
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: SafoColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(SafoRadii.md)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SafoColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SafoColors.surfaceSoft,
          disabledForegroundColor: SafoColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: SafoSpacing.lg,
            vertical: SafoSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SafoRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SafoColors.textPrimary,
          side: const BorderSide(color: SafoColors.border),
          backgroundColor: SafoColors.surface,
          padding: const EdgeInsets.symmetric(
            horizontal: SafoSpacing.lg,
            vertical: SafoSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SafoRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SafoColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: SafoColors.textPrimary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SafoRadii.md),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SafoColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SafoRadii.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SafoColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SafoRadii.xl),
        ),
      ),
    );
  }
}
