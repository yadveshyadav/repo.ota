import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Reusable status badge with a live pulsing dot indicator
class LiveStatusPulse extends StatefulWidget {
  final String label;
  final Color color;
  final bool isLive;
  final bool isCompact;

  const LiveStatusPulse({
    super.key,
    this.label = 'Online LIVE',
    this.color = AppColors.successGreen,
    this.isLive = true,
    this.isCompact = false,
  });

  @override
  State<LiveStatusPulse> createState() => _LiveStatusPulseState();
}

class _LiveStatusPulseState extends State<LiveStatusPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseScale = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );

    _pulseOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );

    if (widget.isLive) {
      _pulseController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCompact ? 6 : 10,
        vertical: widget.isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.isCompact ? 8 : 12,
            height: widget.isCompact ? 8 : 12,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isLive)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseScale.value,
                        child: Opacity(
                          opacity: _pulseOpacity.value,
                          child: Container(
                            width: widget.isCompact ? 6 : 8,
                            height: widget.isCompact ? 6 : 8,
                            decoration: BoxDecoration(
                              color: widget.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  width: widget.isCompact ? 5 : 7,
                  height: widget.isCompact ? 5 : 7,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: widget.isCompact ? 4 : 6),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: widget.isCompact ? 10 : 12,
              fontWeight: FontWeight.bold,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}
