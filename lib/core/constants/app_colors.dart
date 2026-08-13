import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color brandGreen = Color(0xFF3EBA02);
  static const Color brandCyan = Color(0x8C00EDDA); // Color.fromRGBO(0, 237, 218, 0.55)
  static const Color brandDarkBg = Color(0xFF0A0F1D);
  static const Color brandLightBg = Color(0xFFF5F7FA);

  // Gradient
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      brandGreen,
      Color(0x8C00EDDA), // Color.fromRGBO(0, 237, 218, 0.55)
    ],
  );

  static const LinearGradient horizontalBrandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      brandGreen,
      Color(0xFF00EDDA),
    ],
  );

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF0A0E1A);
  static const Color darkCardFill = Color(0x1F1E293B);
  static const Color darkCardBorder = Color(0x14FFFFFF);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light Theme Colors
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCardFill = Color(0xB3FFFFFF);
  static const Color lightCardBorder = Color(0x1A000000);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Task Priority Colors
  static const Color priorityLow = Color(0xFF3B82F6);      // Blue
  static const Color priorityMedium = Color(0xFFF59E0B);   // Amber
  static const Color priorityHigh = Color(0xFFEF4444);     // Red
  static const Color priorityCritical = Color(0xFF7F1D1D); // Deep Red

  // Task Status Colors
  static const Color statusPending = Color(0xFF64748B);    // Slate
  static const Color statusAssigned = Color(0xFF0EA5E9);   // Sky Blue
  static const Color statusInProgress = Color(0xFFF59E0B); // Amber
  static const Color statusReview = Color(0xFFA855F7);     // Purple
  static const Color statusApproved = Color(0xFF10B981);   // Emerald Green
  static const Color statusCompleted = Color(0xFF22C55E);  // Green
  static const Color statusDelayed = Color(0xFFEF4444);    // Red
}
