import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brandGreen,
        secondary: AppColors.brandCyan,
        surface: AppColors.darkBg,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.priorityHigh,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.darkTextPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.darkTextSecondary),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextPrimary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkCardFill,
        shadowColor: Colors.black26,
        elevation: 4,
      ),
      inputDecorationTheme: _inputDecorationTheme(
        borderColor: AppColors.darkCardBorder,
        fillColor: AppColors.darkCardFill,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: _inputDecorationTheme(
          borderColor: AppColors.darkCardBorder,
          fillColor: AppColors.darkCardFill,
        ),
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.darkCardFill),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkBg,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandGreen,
        secondary: AppColors.brandCyan,
        surface: AppColors.lightBg,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.priorityHigh,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.lightTextPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.lightTextPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.lightTextPrimary),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.lightTextSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.lightTextPrimary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.lightCardFill,
        shadowColor: Colors.black12,
        elevation: 2,
      ),
      inputDecorationTheme: _inputDecorationTheme(
        borderColor: AppColors.lightCardBorder,
        fillColor: AppColors.lightCardFill,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: _inputDecorationTheme(
          borderColor: AppColors.lightCardBorder,
          fillColor: AppColors.lightCardFill,
        ),
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.lightCardFill),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.lightBg,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // Shared outlined input styling for TextFields and Dropdowns
  static InputDecorationTheme _inputDecorationTheme({
    required Color borderColor,
    required Color fillColor,
  }) {
    OutlineInputBorder border(Color color, [double width = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border(borderColor),
      enabledBorder: border(borderColor),
      focusedBorder: border(AppColors.brandGreen, 2),
      errorBorder: border(AppColors.priorityHigh),
      focusedErrorBorder: border(AppColors.priorityHigh, 2),
    );
  }

  // Glassmorphism styling helpers
  static BoxDecoration glassDecoration({
    required bool isDark,
    double borderRadius = 12.0,
    double blur = 20.0,
  }) {
    return BoxDecoration(
      color: isDark ? AppColors.darkCardFill : AppColors.lightCardFill,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withOpacity(0.2)
              : Colors.black.withOpacity(0.05),
          blurRadius: blur,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
