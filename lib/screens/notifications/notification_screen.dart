import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../features/attendance/controller/attendance_controller.dart';
import '../../features/auth/services/auth_storage_service.dart';
import '../../models/app_notification.dart';
import '../../repositories/attendance_repository.dart';
import '../../services/notification_service.dart';
import '../attendance/attendance_detail_screen.dart';

/// Screen displaying in-app notifications targeted specifically to the logged-in employee
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.init();
  }

  void _handleNotificationTap(AppNotification notification) async {
    await _notificationService.markAsRead(notification.id);

    if (!mounted) return;

    if (notification.attendanceId != null && notification.attendanceId!.isNotEmpty) {
      final repo = ApiAttendanceRepository();
      final records = await repo.getHistory();
      final matched = records.firstWhere(
        (r) => r.id == notification.attendanceId,
        orElse: () => records.isNotEmpty ? records.first : throw Exception('Record not found'),
      );

      if (mounted) {
        final controller = AttendanceController(repository: repo);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AttendanceDetailScreen(
              attendance: matched,
              controller: controller,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthStorageService().currentUser;
    final userId = user?.id ?? '1';

    return ListenableBuilder(
      listenable: _notificationService,
      builder: (context, child) {
        final userNotifications = _notificationService.getNotificationsForUser(userId);

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          appBar: AppBar(
            backgroundColor: AppColors.headerGreen,
            elevation: 0,
            title: const Text(
              'Notifications',
              style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                tooltip: 'Test Pop-up Notification',
                icon: const Icon(Icons.add_alert_rounded, color: AppColors.white),
                onPressed: () {
                  _notificationService.addNotification(
                    AppNotification(
                      id: 'NOTIF_DEMO_${DateTime.now().millisecondsSinceEpoch}',
                      recipientId: userId,
                      type: 'ATTENDANCE_APPROVED',
                      title: 'Attendance Approved',
                      message: 'Your attendance for today has been approved by ADMIN Sharma.',
                      createdAt: DateTime.now(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: userNotifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.notifications_none_rounded, size: 52, color: AppColors.mutedTextGray),
                        SizedBox(height: 16),
                        Text('No Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                        SizedBox(height: 6),
                        Text('You do not have any new attendance or system notifications at this time.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.mutedTextGray, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: userNotifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final n = userNotifications[index];
                    return _buildNotificationTile(n);
                  },
                ),
        );
      },
    );
  }

  Widget _buildNotificationTile(AppNotification n) {
    final bool isApproved = n.type == 'ATTENDANCE_APPROVED';
    final Color iconColor = isApproved ? AppColors.successGreen : AppColors.criticalRed;
    final IconData iconData = isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      decoration: BoxDecoration(
        color: n.isRead ? AppColors.white : AppColors.lightGreenBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: n.isRead ? AppColors.borderGray : AppColors.primaryGreen.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(n),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead ? FontWeight.bold : FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.deepNavy,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.message,
                      style: const TextStyle(fontSize: 12, color: AppColors.deepNavy, height: 1.3),
                    ),
                    if (n.reason != null && n.reason!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${n.reason}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.criticalRed),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(n.createdAt.toLocal()),
                      style: const TextStyle(fontSize: 10, color: AppColors.mutedTextGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
