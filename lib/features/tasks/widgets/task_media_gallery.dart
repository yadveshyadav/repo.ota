import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/theme/app_text_styles.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/models/task_media_model.dart';
import 'package:hero_app/shared/widgets/safe_image_widget.dart';

/// Full-Screen Media & Evidence Viewer Dialog
class TaskMediaViewerDialog extends StatelessWidget {
  final TaskMediaModel media;

  const TaskMediaViewerDialog({
    super.key,
    required this.media,
  });

  static void open(BuildContext context, TaskMediaModel media) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => TaskMediaViewerDialog(media: media),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  media.label,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Media Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: AppImageWidget(
                photoPath: media.photoUrl,
                fit: BoxFit.contain,
                placeholder: Container(
                  height: 250,
                  width: double.infinity,
                  color: AppColors.deepNavy,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.photo_library_rounded, size: 48, color: AppColors.primaryGreen),
                      SizedBox(height: 8),
                      Text('Evidence Media Record', style: TextStyle(color: AppColors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Metadata Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primaryGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Location: ${media.formattedLocation}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (media.capturedAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: AppColors.infoBlue),
                      const SizedBox(width: 6),
                      Text(
                        'Captured: ${DateParserUtils.formatDisplay(media.capturedAt)}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
                if (media.remarks != null && media.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Remarks: ${media.remarks}',
                    style: const TextStyle(
                      color: AppColors.borderGray,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable Evidence Media Gallery Grid with thumbnail previews
class TaskMediaGalleryWidget extends StatelessWidget {
  final List<TaskMediaModel> mediaList;
  final String title;

  const TaskMediaGalleryWidget({
    super.key,
    required this.mediaList,
    this.title = 'Evidence Gallery',
  });

  @override
  Widget build(BuildContext context) {
    if (mediaList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text(
            'No media attached to this record.',
            style: TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: AppTextStyles.titleMedium.copyWith(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: mediaList.length,
          itemBuilder: (context, index) {
            final item = mediaList[index];

            return InkWell(
              onTap: () => TaskMediaViewerDialog.open(context, item),
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImageWidget(
                      photoPath: item.photoUrl,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: AppColors.softGray,
                        child: const Icon(Icons.photo_outlined, color: AppColors.primaryGreen),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        color: Colors.black54,
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
