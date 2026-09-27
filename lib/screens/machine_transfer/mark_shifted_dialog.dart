import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/machine_transfer/controller/machine_transfer_controller.dart';
import '../../models/machine_movement.dart';

/// Modal Dialog for Field Shifter to Mark Request as SHIFTED with Mandatory Machine Photo
class MarkShiftedDialog extends StatefulWidget {
  final MachineMovement movement;
  final MachineTransferController controller;
  final VoidCallback onSuccess;

  const MarkShiftedDialog({
    super.key,
    required this.movement,
    required this.controller,
    required this.onSuccess,
  });

  @override
  State<MarkShiftedDialog> createState() => _MarkShiftedDialogState();
}

class _MarkShiftedDialogState extends State<MarkShiftedDialog> {
  final ImagePicker _picker = ImagePicker();

  XFile? _capturedPhoto;
  Uint8List? _photoBytes;

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _expenseController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  String _shiftingMode = 'OWN_HDD';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _shiftingMode = widget.movement.modeOfShifting.isNotEmpty ? widget.movement.modeOfShifting : 'OWN_HDD';
    _contactController.text = widget.movement.shiftingContactPerson ?? 'Field Shifter (+91 9876543210)';
    _expenseController.text = widget.movement.shiftingExpenseAmount ?? '0.00';
    _remarksController.text = widget.movement.remarks ?? '';
  }

  @override
  void dispose() {
    _dateController.dispose();
    _contactController.dispose();
    _expenseController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedPhoto = photo;
          _photoBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e'), backgroundColor: AppColors.criticalRed),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_photoBytes == null || _photoBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mandatory: Please capture a machine photo at destination Point B.'),
          backgroundColor: AppColors.criticalRed,
        ),
      );
      return;
    }

    if (_contactController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter contact person name & phone.'),
          backgroundColor: AppColors.criticalRed,
        ),
      );
      return;
    }

    final success = await widget.controller.markShifted(
      requestId: widget.movement.id,
      shiftingDate: _dateController.text.trim(),
      shiftingMode: _shiftingMode,
      shiftingContactPerson: _contactController.text.trim(),
      shiftingExpenseAmount: _expenseController.text.trim().isNotEmpty ? _expenseController.text.trim() : '0.00',
      photoBytes: _photoBytes,
      photoFilename: _capturedPhoto?.name ?? 'rig_photo.jpg',
      remarks: _remarksController.text.trim(),
    );

    if (mounted && success) {
      Navigator.of(context).pop();
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mark as Shifted', style: AppTextStyles.headingMedium),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload mandatory machine destination picture and complete field shifting record.',
                style: AppTextStyles.bodyMedium,
              ),

              const SizedBox(height: 16),

              // Camera Photo Preview Box
              const Text('DESTINATION MACHINE PHOTO *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _pickPhoto(ImageSource.camera),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.softGray,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _photoBytes != null ? AppColors.primaryGreen : AppColors.borderGray,
                      width: _photoBytes != null ? 2 : 1,
                    ),
                  ),
                  child: _photoBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_photoBytes!, fit: BoxFit.cover),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 12, color: AppColors.successGreen),
                                      SizedBox(width: 4),
                                      Text('Photo Captured', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryGreen, size: 28),
                            ),
                            const SizedBox(height: 8),
                            const Text('Tap to capture machine photo at Point B', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                            const SizedBox(height: 2),
                            const Text('Mandatory field photo required by backend', style: AppTextStyles.caption),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Form Fields
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SHIFTING DATE *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _dateController,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EXPENSE AMOUNT (₹) *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _expenseController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Text('CONTACT PERSON & PHONE *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
              const SizedBox(height: 4),
              TextField(
                controller: _contactController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Ramesh Kumar (+91 9876543210)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),

              const SizedBox(height: 12),

              const Text('REMARKS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mutedTextGray)),
              const SizedBox(height: 4),
              TextField(
                controller: _remarksController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Rig reached Block C and unloaded safely',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),

              const SizedBox(height: 20),

              // Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.controller.isSubmitting ? null : _handleSubmit,
                  icon: widget.controller.isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(widget.controller.isSubmitting ? 'UPLOADING...' : 'MARK AS SHIFTED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
