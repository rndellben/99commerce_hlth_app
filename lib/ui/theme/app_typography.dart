import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

class AppTypography {
  AppTypography._();

  static const TextTheme textTheme = TextTheme(
    // Large metric displays (e.g., "72" bpm, "97" SpO2)
    displayLarge: TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.1,
    ),
    displayMedium: TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.1,
    ),
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      height: 1.2,
    ),
    // Score values (e.g., "74/100")
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    // Card titles, section headers
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    // Body text
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textTertiary,
    ),
    // Labels, units (e.g., "bpm", "steps")
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppColors.textTertiary,
      letterSpacing: 0.5,
    ),
  );
}
