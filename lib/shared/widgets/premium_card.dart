import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Reusable enterprise Card component providing a consistent visual foundation
class PremiumCard extends StatefulWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool enableHover;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const PremiumCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(20.0),
    this.borderRadius = 14.0,
    this.onTap,
    this.enableHover = true,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = _isHovered
        ? AppColors.primaryGreen.withValues(alpha: 0.35)
        : AppColors.borderGray;

    final translateY = _isHovered ? -2.0 : 0.0;

    return MouseRegion(
      onEnter: widget.enableHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.enableHover ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, translateY, 0),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? AppColors.primaryGreen.withValues(alpha: 0.08)
                  : AppColors.shadowColor,
              blurRadius: _isHovered ? 12 : 4,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Padding(
              padding: widget.padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.title != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title!,
                                style: AppTextStyles.headingSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle!,
                                  style: AppTextStyles.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.trailing != null) ...[
                          const SizedBox(width: 8),
                          widget.trailing!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  else if (widget.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.criticalRed, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              widget.errorMessage!,
                              style: AppTextStyles.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            if (widget.onRetry != null) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: widget.onRetry,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    widget.child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
