import 'package:flutter/material.dart';

/// Lightweight staggered entrance animation for mobile list items & cards (Fade + Slide Up)
class HeroAnimatedItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;

  const HeroAnimatedItem({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  State<HeroAnimatedItem> createState() => _HeroAnimatedItemState();
}

class _HeroAnimatedItemState extends State<HeroAnimatedItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Stagger delay based on list index (clamped to max 5 items delay)
    final delayMs = (widget.index.clamp(0, 5)) * 40;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}
