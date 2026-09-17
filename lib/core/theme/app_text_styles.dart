import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized text styles for HERO APP enforcing clean sans-serif typography.
abstract class AppTextStyles {
  static const String _fontFamily = 'sans-serif';

  /// Display Large - Splash branding or major screens
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Display Medium - Main titles
  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    letterSpacing: -0.3,
    height: 1.25,
  );

  /// Heading Large - Screen headings ("Welcome back")
  static const TextStyle headingLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    letterSpacing: -0.2,
    height: 1.3,
  );

  /// Heading Medium - Section headers
  static const TextStyle headingMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    height: 1.35,
  );

  /// Heading Small - Card titles / Sub-headers
  static const TextStyle headingSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.deepNavy,
    height: 1.35,
  );

  /// Machine Title - Machine Model Name in Machine List
  static const TextStyle machineTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    letterSpacing: -0.2,
  );

  /// Machine ID / Chassis Number - Clean, high contrast, readable style
  static const TextStyle machineId = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    letterSpacing: 0.8,
  );

  /// Tagline style - Splash screen tagline
  static const TextStyle splashTagline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.deepNavy,
    letterSpacing: 0.2,
    height: 1.4,
  );

  /// Title Large - Input field labels & prominent subtitles
  static const TextStyle titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.deepNavy,
  );

  /// Title Medium - Standard field labels
  static const TextStyle titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.deepNavy,
  );

  /// Body Large - Prominent paragraphs & input values
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.deepNavy,
    height: 1.4,
  );

  /// Body Medium - Standard body copy & descriptions
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedTextGray,
    height: 1.45,
  );

  /// Body Small - Secondary supporting text
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedTextGray,
    height: 1.4,
  );

  /// Input hint / placeholder text
  static const TextStyle inputHint = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedTextGray,
  );

  /// Label Large - Primary button text
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    letterSpacing: 0.3,
  );

  /// Label Medium - Text buttons & action links
  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.darkHeroGreen,
  );

  /// Caption - Version labels, metadata & fine print
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedTextGray,
    letterSpacing: 0.2,
  );

  /// Error text
  static const TextStyle errorText = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.errorRed,
  );
}
