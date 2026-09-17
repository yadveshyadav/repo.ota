import 'package:flutter/services.dart';

/// Native Android MethodChannel abstraction for package installation & FileProvider
class OtaInstaller {
  static const MethodChannel _channel = MethodChannel('com.infocrats.hero/ota_installer');

  /// Check whether app has REQUEST_INSTALL_PACKAGES permission on Android 8.0+
  static Future<bool> canRequestPackageInstalls() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Open Android settings page for enabling unknown app sources for this app
  static Future<bool> openInstallPermissionSettings() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('openInstallPermissionSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Trigger Android package installer for downloaded APK file path
  static Future<bool> installApk(String filePath) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_REQUIRED') {
        throw Exception('INSTALL_PERMISSION_REQUIRED');
      }
      throw Exception('Installation failed: ${e.message}');
    } catch (e) {
      throw Exception('Installation failed: $e');
    }
  }
}
