import 'package:flutter/material.dart';

/// Utility class for responsive layout adjustments.
class Responsive {
  final BuildContext context;

  Responsive(this.context);

  static Responsive of(BuildContext context) => Responsive(context);

  Size get size => MediaQuery.of(context).size;
  double get width => size.width;
  double get height => size.height;

  bool get isSmallPhone => width < 360 || height < 640;
  bool get isTablet => width >= 600;

  /// Proportional horizontal padding
  double horizontalPadding([double factor = 0.06]) {
    final computed = width * factor;
    return computed.clamp(16.0, 36.0);
  }

  /// Proportional vertical spacing
  double verticalSpacing([double factor = 0.02]) {
    final computed = height * factor;
    return computed.clamp(8.0, 32.0);
  }

  /// Adaptive logo width reduced by 40% for compact/screen views
  double logoWidth({bool isCompact = false}) {
    if (isCompact) {
      return (width * 0.28).clamp(80.0, 115.0);
    }
    return (width * 0.35).clamp(100.0, 150.0);
  }
}
