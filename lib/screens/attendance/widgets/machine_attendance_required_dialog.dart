import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/screens/attendance/assigned_machines_screen.dart';

/// Popup dialog alerting user that assigned machine attendance must be marked first
class MachineAttendanceRequiredDialog extends StatelessWidget {
  final AttendanceController controller;

  const MachineAttendanceRequiredDialog({
    super.key,
    required this.controller,
  });

  static Future<bool?> show(BuildContext context, AttendanceController controller) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MachineAttendanceRequiredDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 28),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Machine Attendance Required',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.deepNavy,
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        'You have assigned machine(s) whose attendance has not been marked for today. Please mark your machine attendance first before marking team attendance.',
        style: TextStyle(fontSize: 13, color: AppColors.deepNavy),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.mutedTextGray)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context, true);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AssignedMachinesScreen(controller: controller),
              ),
            );
          },
          icon: const Icon(Icons.precision_manufacturing_rounded, size: 18),
          label: const Text('Mark Machine Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
