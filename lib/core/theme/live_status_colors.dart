import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized status visual colors and badges for Live Status machine states
abstract class LiveStatusColors {
  /// Status Colors
  static const Color online = AppColors.successGreen; // #10B981
  static const Color working = AppColors.successGreen; // #10B981
  static const Color moving = AppColors.movingBlue; // #0284C7
  static const Color idle = AppColors.idleAmber; // #F59E0B
  static const Color onBattery = Color(0xFF64748B); // neutral/slate
  static const Color keyOnEngineOff = AppColors.warningAmber; // #F59E0B
  static const Color towing = AppColors.movingBlue; // #0284C7
  static const Color offline = AppColors.criticalRed; // #EF4444
  static const Color powerCut = AppColors.errorRed; // #DC2626

  /// Helper to get main status accent color for Operational State
  static Color getOperationalStateColor(String stateName) {
    final lower = stateName.toLowerCase().replaceAll(' ', '');
    if (lower.contains('working')) return working;
    if (lower.contains('moving')) return moving;
    if (lower.contains('idle')) return idle;
    if (lower.contains('battery')) return onBattery;
    if (lower.contains('keyon') || lower.contains('key')) return keyOnEngineOff;
    if (lower.contains('towing')) return towing;
    if (lower.contains('powercut') || lower.contains('cut')) return powerCut;
    if (lower.contains('offline')) return offline;
    return online;
  }

  /// Helper to get background color for status chip
  static Color getStatusBgColor(Color mainColor) {
    return mainColor.withValues(alpha: 0.12);
  }
}
