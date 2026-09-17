import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/core/update/models/ota_update_info.dart';
import 'package:hero_app/core/update/services/ota_download_service.dart';
import 'package:hero_app/core/update/services/ota_installer.dart';
import 'package:hero_app/core/update/services/ota_update_service.dart';

/// Central Helper & Dialog Workflows for Hero OTA Update
class OtaUpdateDialogs {
  /// Execute central check for app updates and show mandatory dialog or status feedback
  static Future<void> performAppUpdateCheck(
    BuildContext context, {
    bool isManualCheck = false,
    OtaUpdateService? updateService,
  }) async {
    final service = updateService ?? OtaUpdateService();

    if (isManualCheck) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                ),
                SizedBox(width: 16),
                Text(
                  'Checking for app updates...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final checkResult = await service.checkForUpdates();

    if (isManualCheck && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!context.mounted) return;

    if (checkResult.isUpdateAvailable && checkResult.updateInfo != null) {
      // Show non-dismissible mandatory update dialog
      final shouldUpdate = await showUpdateAvailableDialog(
        context,
        currentVersion: checkResult.installedVersionName,
        updateInfo: checkResult.updateInfo!,
        isMandatory: true,
      );

      if (shouldUpdate == true && context.mounted) {
        await startDownloadAndInstallWorkflow(
          context,
          updateInfo: checkResult.updateInfo!,
        );
      }

      // Re-trigger update check to keep usage blocked if update was not completed
      if (context.mounted) {
        performAppUpdateCheck(context, isManualCheck: false, updateService: service);
      }
    } else if (isManualCheck) {
      if (checkResult.errorMessage != null) {
        showErrorDialog(
          context,
          message: checkResult.errorMessage!,
          onRetry: () => performAppUpdateCheck(context, isManualCheck: true, updateService: service),
        );
      } else {
        showUpToDateDialog(
          context,
          currentVersion: checkResult.installedVersionName,
        );
      }
    }
  }

  /// Show "Update Available" Dialog (Mandatory update blocks older app versions)
  static Future<bool?> showUpdateAvailableDialog(
    BuildContext context, {
    required String currentVersion,
    required OtaUpdateInfo updateInfo,
    bool isMandatory = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (ctx) => PopScope(
        canPop: !isMandatory,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: AppColors.primaryGreen,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Update Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isMandatory ? 'A mandatory update is required to continue' : 'New version available',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softGray,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Installed Version', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                        const SizedBox(height: 2),
                        Text(currentVersion, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.mutedTextGray),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Required Version', style: TextStyle(fontSize: 10, color: AppColors.mutedTextGray)),
                        const SizedBox(height: 2),
                        Text(updateInfo.versionName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (isMandatory)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warningAmber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Previous app versions are no longer supported. Please update to continue using Hero.',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                        ),
                      ),
                    ],
                  ),
                ),

              if (updateInfo.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'What\'s New',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: AppColors.softGray.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      updateInfo.releaseNotes,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.deepNavy,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!isMandatory)
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Later', style: TextStyle(color: AppColors.mutedTextGray, fontWeight: FontWeight.bold)),
              ),
            SizedBox(
              width: isMandatory ? double.infinity : null,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
    );
  }

  /// Show "Up To Date" Dialog according to Section 12
  static void showUpToDateDialog(
    BuildContext context, {
    required String currentVersion,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.successGreen,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hero is up to date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.deepNavy,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current version: $currentVersion',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'You are using the latest available version of Hero.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedTextGray,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Show Download Progress Dialog and trigger installer workflow
  static Future<void> startDownloadAndInstallWorkflow(
    BuildContext context, {
    required OtaUpdateInfo updateInfo,
    OtaDownloadService? downloadService,
  }) async {
    final downloader = downloadService ?? OtaDownloadService();

    // Check if a valid APK file is already cached on disk for this version
    File? apkFile = await downloader.getCachedApkFile(updateInfo.versionCode);

    if (apkFile == null) {
      if (!context.mounted) return;
      apkFile = await _showDownloadProgressDialog(
        context,
        updateInfo: updateInfo,
        downloader: downloader,
      );
    }

    if (apkFile == null || !context.mounted) {
      return;
    }

    await _promptAndInstallApk(context, apkFile, updateInfo);
  }

  /// Downloads APK with UI progress feedback and returns the File if successful
  static Future<File?> _showDownloadProgressDialog(
    BuildContext context, {
    required OtaUpdateInfo updateInfo,
    required OtaDownloadService downloader,
  }) async {
    int downloadedBytes = 0;
    int totalBytes = 0;
    double progress = 0.0;
    String? errorMessage;
    File? downloadedFile;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            void runDownload() async {
              setState(() {
                errorMessage = null;
                progress = 0.0;
              });

              try {
                final file = await downloader.downloadApk(
                  apkUrl: updateInfo.apkUrl,
                  versionCode: updateInfo.versionCode,
                  onProgress: (received, total) {
                    if (context.mounted) {
                      setState(() {
                        downloadedBytes = received;
                        totalBytes = total;
                        progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
                      });
                    }
                  },
                );

                downloadedFile = file;

                // Close progress dialog on success
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
              } catch (e) {
                if (context.mounted) {
                  setState(() {
                    errorMessage = 'Unable to download update: ${e.toString().replaceAll("Exception: ", "")}';
                  });
                }
              }
            }

            // Start download once on dialog mount
            if (downloadedBytes == 0 && errorMessage == null && downloadedFile == null) {
              runDownload();
            }

            final percentStr = (progress * 100).toStringAsFixed(0);
            final downloadedMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
            final totalMb = totalBytes > 0 ? (totalBytes / (1024 * 1024)).toStringAsFixed(1) : '?';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                children: [
                  const Text(
                    'Hero Update',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Downloading version ${updateInfo.versionName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedTextGray),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.criticalRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: AppColors.criticalRed, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.softGray,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$percentStr%',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                        Text(
                          'Downloaded: $downloadedMb MB / $totalMb MB',
                          style: const TextStyle(fontSize: 11, color: AppColors.mutedTextGray),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                if (errorMessage != null) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.mutedTextGray)),
                  ),
                  ElevatedButton(
                    onPressed: () => runDownload(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.mutedTextGray)),
                  ),
                ],
              ],
            );
          },
        );
      },
    );

    return downloadedFile;
  }

  /// Handles install permission checking and triggering native Android APK installer
  static Future<void> _promptAndInstallApk(
    BuildContext context,
    File apkFile,
    OtaUpdateInfo updateInfo,
  ) async {
    bool canInstall = await OtaInstaller.canRequestPackageInstalls();

    if (!canInstall) {
      if (!context.mounted) return;
      final bool granted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _PermissionRequiredDialog(),
      ) ?? false;

      if (!granted) {
        return;
      }
      canInstall = await OtaInstaller.canRequestPackageInstalls();
    }

    if (canInstall) {
      try {
        await OtaInstaller.installApk(apkFile.path);
      } catch (e) {
        if (context.mounted) {
          showErrorDialog(
            context,
            message: 'Installation failed: ${e.toString().replaceAll("Exception: ", "")}',
            onRetry: () => _promptAndInstallApk(context, apkFile, updateInfo),
          );
        }
      }
    }
  }

  /// Show Error Dialog when update check fails
  static void showErrorDialog(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.error_outline_rounded, color: AppColors.criticalRed, size: 22),
            SizedBox(width: 8),
            Text('Update Check Failed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepNavy)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, color: AppColors.deepNavy),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.mutedTextGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRetry();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Dialog prompting user to enable "Install Unknown Apps" permission in Settings
/// and automatically checks permission when app resumes from Settings.
class _PermissionRequiredDialog extends StatefulWidget {
  const _PermissionRequiredDialog();

  @override
  State<_PermissionRequiredDialog> createState() => _PermissionRequiredDialogState();
}

class _PermissionRequiredDialogState extends State<_PermissionRequiredDialog> with WidgetsBindingObserver {
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionOnResume();
    }
  }

  Future<void> _checkPermissionOnResume() async {
    if (_isChecking) return;
    _isChecking = true;

    final hasPermission = await OtaInstaller.canRequestPackageInstalls();
    if (mounted) {
      if (hasPermission) {
        Navigator.of(context).pop(true);
      } else {
        _isChecking = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.security_rounded,
              color: AppColors.warningAmber,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Permission Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.deepNavy,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'To install updates, Hero app requires permission to install unknown apps.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.deepNavy,
              height: 1.4,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Tap "Open Settings" below and enable "Allow from this source", then return to the app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.mutedTextGray)),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await OtaInstaller.openInstallPermissionSettings();
          },
          icon: const Icon(Icons.settings_rounded, size: 18),
          label: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.bold)),
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
