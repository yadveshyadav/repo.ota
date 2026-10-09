import 'dart:ui';

import 'package:flutter/material.dart';

/// A lightly translucent surface for Hindrance/CCN content sections.
/// The blur is clipped to the card; controls and their hit testing stay intact.
class HindranceGlassSurface extends StatelessWidget {
  const HindranceGlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.radius = 18,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16432E).withValues(alpha: 0.09),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  const Color(0xFFF5FAF7).withValues(alpha: 0.74),
                  Colors.white.withValues(alpha: 0.80),
                ],
              ),
              borderRadius: borderRadius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.96),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Soft color glows add a backdrop for the translucent panels without
/// intercepting taps or changing the app's existing green-and-neutral palette.
class HindranceGlassBackdrop extends StatelessWidget {
  const HindranceGlassBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F8F5), Color(0xFFF7F8FA), Color(0xFFF0F5F2)],
          ),
        ),
      ),
      Positioned(
        top: -100,
        right: -90,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8DC9A2).withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 60,
        left: -130,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFA9C9DD).withValues(alpha: 0.20),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}
