import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Единая тема приложения на основе AppColors.
/// Подключается в main.dart как theme и darkTheme.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary500,
        onPrimary: AppColors.textInverse,
        primaryContainer: AppColors.primary100,
        onPrimaryContainer: AppColors.primary700,
        secondary: AppColors.secondary500,
        onSecondary: AppColors.textPrimary,
        surface: AppColors.backgroundPrimary,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.backgroundSecondary,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.borderPrimary,
        error: AppColors.error500,
        onError: AppColors.textInverse,
      ),
      scaffoldBackgroundColor: AppColors.backgroundSecondary,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.backgroundPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary500,
          foregroundColor: AppColors.textInverse,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary500,
          foregroundColor: AppColors.textInverse,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundPrimary,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderPrimary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.primary100,
        checkmarkColor: AppColors.primary500,
        side: const BorderSide(color: AppColors.borderPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary500;
          return AppColors.neutral400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary100;
          return AppColors.neutral200;
        }),
      ),
      dividerColor: AppColors.borderPrimary,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary500,
        circularTrackColor: AppColors.neutral200,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        contentTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
        backgroundColor: AppColors.neutral800,
        showCloseIcon: false,
      ),
    );
  }
}
