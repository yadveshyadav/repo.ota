import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../models/ota_update_info.dart';

class OtaCheckResult {
  final bool isUpdateAvailable;
  final OtaUpdateInfo? updateInfo;
  final int installedVersionCode;
  final String installedVersionName;
  final String? errorMessage;

  const OtaCheckResult({
    required this.isUpdateAvailable,
    this.updateInfo,
    required this.installedVersionCode,
    required this.installedVersionName,
    this.errorMessage,
  });
}

/// Central Service managing OTA metadata fetching, version comparison, and update checks
class OtaUpdateService {
  static const String defaultMetadataUrl =
      'https://raw.githubusercontent.com/yadveshyadav/hero.ota/main/update.json';

  final http.Client _client;
  final String metadataUrl;

  OtaUpdateService({
    http.Client? client,
    this.metadataUrl = defaultMetadataUrl,
  }) : _client = client ?? http.Client();

  /// Reads installed application PackageInfo
  Future<PackageInfo> getInstalledAppInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return PackageInfo(
        appName: 'Hero',
        packageName: 'com.infocrats.hero',
        version: '1.0.0',
        buildNumber: '1',
      );
    }
  }

  /// Fetches remote update.json and parses strongly typed OtaUpdateInfo
  Future<OtaUpdateInfo> fetchRemoteUpdateInfo() async {
    try {
      final response = await _client.get(Uri.parse(metadataUrl)).timeout(
        const Duration(seconds: 12),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final bodyStr = response.body.trim();
      if (bodyStr.isEmpty) {
        throw Exception('Empty response from update server');
      }

      final Map<String, dynamic> jsonMap = jsonDecode(bodyStr);
      return OtaUpdateInfo.fromJson(jsonMap);
    } catch (e) {
      if (kDebugMode) {
        print('[OtaUpdateService] Fetch metadata error: $e');
      }
      rethrow;
    }
  }

  /// Executes check for updates: gets installed version, fetches remote metadata, compares version codes numerically
  Future<OtaCheckResult> checkForUpdates({
    int? mockInstalledVersionCode,
    String? mockInstalledVersionName,
  }) async {
    int installedCode = 1;
    String installedName = '1.0.0';

    if (mockInstalledVersionCode != null) {
      installedCode = mockInstalledVersionCode;
      installedName = mockInstalledVersionName ?? '$installedCode.0';
    } else {
      final packageInfo = await getInstalledAppInfo();
      installedName = packageInfo.version;
      installedCode = int.tryParse(packageInfo.buildNumber) ?? 1;
    }

    try {
      final remoteInfo = await fetchRemoteUpdateInfo();
      final bool isAvailable = remoteInfo.versionCode > installedCode &&
          _isVersionHigher(remoteInfo.versionName, installedName);

      return OtaCheckResult(
        isUpdateAvailable: isAvailable,
        updateInfo: remoteInfo,
        installedVersionCode: installedCode,
        installedVersionName: installedName,
      );
    } catch (e) {
      return OtaCheckResult(
        isUpdateAvailable: false,
        installedVersionCode: installedCode,
        installedVersionName: installedName,
        errorMessage: _formatErrorMessage(e),
      );
    }
  }

  /// Compares two version strings (e.g. "1.0.1" vs "1.0.0").
  /// Returns true if [remoteVersion] is strictly greater than [installedVersion].
  bool _isVersionHigher(String remoteVersion, String installedVersion) {
    try {
      final remoteParts = remoteVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final installedParts = installedVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = remoteParts.length > installedParts.length ? remoteParts.length : installedParts.length;

      for (int i = 0; i < maxLength; i++) {
        final remoteNum = i < remoteParts.length ? remoteParts[i] : 0;
        final installedNum = i < installedParts.length ? installedParts[i] : 0;

        if (remoteNum > installedNum) return true;
        if (remoteNum < installedNum) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String _formatErrorMessage(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('timeout')) {
      return 'Connection timed out. Please check your internet connection.';
    }
    if (str.contains('socket') || str.contains('connection') || str.contains('network')) {
      return 'Unable to connect to the update server. Please check your internet connection.';
    }
    return 'Unable to check for updates. Please try again later.';
  }
}
