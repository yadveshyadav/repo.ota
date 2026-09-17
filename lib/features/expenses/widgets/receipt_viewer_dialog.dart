import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/safe_image_widget.dart';

/// Full-screen Receipt & Attachment Viewer with Zoom & Pan Support
class ReceiptViewerDialog extends StatelessWidget {
  final String attachmentUrl;
  final String? title;

  const ReceiptViewerDialog({
    super.key,
    required this.attachmentUrl,
    this.title,
  });

  static void show(BuildContext context, {required String attachmentUrl, String? title}) {
    showDialog(
      context: context,
      builder: (ctx) => ReceiptViewerDialog(
        attachmentUrl: attachmentUrl,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Container(
              color: AppColors.headerGreen,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title ?? 'Bill / Receipt Attachment',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Image Container with InteractiveViewer
            Container(
              constraints: const BoxConstraints(maxHeight: 500, minHeight: 250),
              color: AppColors.backgroundGray,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: AppImageWidget(
                    photoPath: attachmentUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
