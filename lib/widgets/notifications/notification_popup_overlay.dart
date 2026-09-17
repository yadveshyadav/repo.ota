import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_globals.dart';
import '../../models/app_notification.dart';

/// Animated Top Pop-up Banner Overlay for In-App Notifications
class NotificationPopupOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _autoDismissTimer;

  /// Display a floating pop-up notification banner at top of active screen
  static void show({
    required AppNotification notification,
    BuildContext? context,
    VoidCallback? onTap,
    Duration autoDismissDuration = const Duration(seconds: 5),
  }) {
    // Dismiss any existing active popup
    dismiss();

    final targetContext = context ?? AppGlobals.navigatorKey.currentContext;
    if (targetContext == null) return;

    final overlayState = Overlay.maybeOf(targetContext) ??
        AppGlobals.navigatorKey.currentState?.overlay;

    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _NotificationPopupWidget(
        notification: notification,
        onDismiss: () => dismiss(),
        onTap: () {
          dismiss();
          if (onTap != null) {
            onTap();
          } else {
            // Navigate to Notifications Screen
            final nav = AppGlobals.navigatorKey.currentState;
            if (nav != null) {
              nav.pushNamed(AppRoutes.notifications);
            }
          }
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    _autoDismissTimer = Timer(autoDismissDuration, () {
      dismiss();
    });
  }

  /// Manually dismiss current pop-up notification banner
  static void dismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;

    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _NotificationPopupWidget extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotificationPopupWidget({
    required this.notification,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_NotificationPopupWidget> createState() => _NotificationPopupWidgetState();
}

class _NotificationPopupWidgetState extends State<_NotificationPopupWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnim = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
  }

  Future<void> _handleDismiss() async {
    await _animController.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    final type = widget.notification.type.toUpperCase();
    if (type.contains('APPROVED') || type.contains('SUCCESS')) {
      return AppColors.primaryGreen;
    } else if (type.contains('REJECTED') || type.contains('FAIL') || type.contains('CANCEL')) {
      return AppColors.criticalRed;
    } else if (type.contains('WARNING') || type.contains('ALERT')) {
      return AppColors.warningAmber;
    }
    return AppColors.deepNavy;
  }

  IconData get _icon {
    final type = widget.notification.type.toUpperCase();
    if (type.contains('APPROVED') || type.contains('SUCCESS')) {
      return Icons.check_circle_rounded;
    } else if (type.contains('REJECTED') || type.contains('FAIL')) {
      return Icons.cancel_rounded;
    } else if (type.contains('WARNING') || type.contains('ALERT')) {
      return Icons.warning_amber_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top > 0 ? mediaQuery.padding.top + 8 : 16.0;

    return Positioned(
      top: topPadding,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _offsetAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -4) {
                _handleDismiss();
              }
            },
            onTap: widget.onTap,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderGray, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: _accentColor, width: 5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Icon Badge
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accentColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_icon, color: _accentColor, size: 22),
                        ),
                        const SizedBox(width: 12),

                        // Title & Body Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.notification.title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.deepNavy,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundGray,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'NOW',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.mutedTextGray,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.notification.message,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.deepNavy,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Actions: View & Close (X)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _handleDismiss,
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(Icons.close_rounded, size: 18, color: AppColors.mutedTextGray),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'VIEW',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
