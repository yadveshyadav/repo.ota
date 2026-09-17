import 'package:flutter/material.dart';

/// Smooth, high-performance mobile page transition with subtle Fade + Horizontal/Vertical Slide
class HeroPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  HeroPageRoute({
    required this.builder,
    super.settings,
    Duration duration = const Duration(milliseconds: 250),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnim = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnim),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0.0),
                  end: Offset.zero,
                ).animate(curvedAnim),
                child: child,
              ),
            );
          },
        );
}
