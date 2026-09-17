import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hero_app/core/constants/app_constants.dart';
import 'package:hero_app/core/theme/app_colors.dart';

/// Cross-platform safe Image loader Widget handling File, Network, Data URL, Base64, and Memory images
class AppImageWidget extends StatelessWidget {
  final String? photoPath;
  final Uint8List? photoBytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const AppImageWidget({
    super.key,
    this.photoPath,
    this.photoBytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = placeholder ??
        const Center(
          child: Icon(Icons.person_rounded, size: 36, color: AppColors.mutedTextGray),
        );

    // 1. Direct photo bytes provided
    if (photoBytes != null && photoBytes!.isNotEmpty) {
      return Image.memory(
        photoBytes!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    final path = photoPath;
    if (path == null || path.trim().isEmpty) {
      return fallback;
    }

    final trimmedPath = path.trim();

    // 2. Data URL (e.g. "data:image/jpeg;base64,/9j/4AAQSkZJRg...")
    if (trimmedPath.startsWith('data:')) {
      return _buildFromDataUrl(trimmedPath, fallback);
    }

    // 3. HTTP / HTTPS Network URL
    if (trimmedPath.startsWith('http://') || trimmedPath.startsWith('https://')) {
      return Image.network(
        trimmedPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    // 3b. Relative Web Portal Media URL (e.g. "/media/photos/...")
    if (trimmedPath.startsWith('/media/') ||
        trimmedPath.startsWith('/static/') ||
        trimmedPath.startsWith('/uploads/') ||
        trimmedPath.startsWith('/photos/') ||
        trimmedPath.startsWith('/images/')) {
      final fullUrl = '${AppConstants.defaultBaseUrl}$trimmedPath';
      return Image.network(
        fullUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    // 4. Flutter Asset
    if (trimmedPath.startsWith('assets/')) {
      return Image.asset(
        trimmedPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    // 5. Local File
    if (!kIsWeb) {
      try {
        final cleanPath = trimmedPath.startsWith('file://')
            ? trimmedPath.substring(7)
            : trimmedPath;
        final file = File(cleanPath);
        if (file.existsSync() && file.lengthSync() > 0) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => fallback,
          );
        }
      } catch (_) {}
    }

    // 6. Fallback check for raw Base64 string without data: header
    if (_isBase64(trimmedPath)) {
      return _buildFromBase64(trimmedPath, fallback);
    }

    return fallback;
  }

  Widget _buildFromDataUrl(String dataUrl, Widget fallback) {
    try {
      final commaIndex = dataUrl.indexOf(',');
      final base64Part = commaIndex != -1 ? dataUrl.substring(commaIndex + 1) : dataUrl;
      final bytes = base64Decode(base64Part.replaceAll(RegExp(r'\s+'), ''));
      if (bytes.isNotEmpty) {
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    } catch (_) {}
    return fallback;
  }

  Widget _buildFromBase64(String base64Str, Widget fallback) {
    try {
      final cleanStr = base64Str.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(cleanStr);
      if (bytes.isNotEmpty) {
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    } catch (_) {}
    return fallback;
  }

  bool _isBase64(String str) {
    if (str.length < 16) return false;
    final clean = str.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(clean);
  }
}
