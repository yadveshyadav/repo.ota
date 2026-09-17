import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

typedef OnDownloadProgress = void Function(int bytesDownloaded, int totalBytes);

/// Dedicated Service managing async APK download, progress tracking, and file integrity verification
class OtaDownloadService {
  final http.Client _client;

  OtaDownloadService({http.Client? client}) : _client = client ?? http.Client();

  /// Returns cached APK file if present, non-empty, and matches given versionCode
  Future<File?> getCachedApkFile(int versionCode) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/hero_update.apk');
      final metaFile = File('${tempDir.path}/hero_update_meta.json');

      if (!await apkFile.exists() || !await metaFile.exists()) {
        return null;
      }

      final length = await apkFile.length();
      if (length == 0) {
        await clearCachedApk();
        return null;
      }

      final metaContent = await metaFile.readAsString();
      final metaJson = jsonDecode(metaContent) as Map<String, dynamic>;
      final savedVersionCode = metaJson['versionCode'] as int?;

      if (savedVersionCode == versionCode) {
        if (kDebugMode) {
          print('[OtaDownloadService] Found valid cached APK for versionCode $versionCode ($length bytes)');
        }
        return apkFile;
      } else {
        await clearCachedApk();
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[OtaDownloadService] Error reading cached APK metadata: $e');
      }
      await clearCachedApk();
      return null;
    }
  }

  /// Save metadata JSON for downloaded APK
  Future<void> saveApkMetadata(int versionCode) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final metaFile = File('${tempDir.path}/hero_update_meta.json');
      final metaJson = {
        'versionCode': versionCode,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await metaFile.writeAsString(jsonEncode(metaJson));
    } catch (e) {
      if (kDebugMode) {
        print('[OtaDownloadService] Failed to save APK metadata: $e');
      }
    }
  }

  /// Deletes cached update APK and metadata file
  Future<void> clearCachedApk() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/hero_update.apk');
      final metaFile = File('${tempDir.path}/hero_update_meta.json');

      if (await apkFile.exists()) {
        await apkFile.delete();
      }
      if (await metaFile.exists()) {
        await metaFile.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[OtaDownloadService] Error clearing cached APK: $e');
      }
    }
  }

  /// Download APK from HTTPS URL with progress callback
  Future<File> downloadApk({
    required String apkUrl,
    required OnDownloadProgress onProgress,
    int? versionCode,
  }) async {
    if (!apkUrl.toLowerCase().startsWith('https://')) {
      throw Exception('Invalid URL protocol. Only HTTPS downloads are allowed for security.');
    }

    try {
      await clearCachedApk();

      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await _client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned HTTP ${response.statusCode} while fetching update APK.');
      }

      final contentLength = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/hero_update.apk');

      final sink = apkFile.openWrite();
      int downloadedBytes = 0;

      await for (final chunk in response.stream) {
        downloadedBytes += chunk.length;
        sink.add(chunk);
        onProgress(downloadedBytes, contentLength);
      }

      await sink.flush();
      await sink.close();

      // Verify file integrity
      if (!await apkFile.exists()) {
        throw Exception('Downloaded file was not saved.');
      }
      final length = await apkFile.length();
      if (length == 0) {
        await apkFile.delete();
        throw Exception('Downloaded APK file is empty (0 bytes).');
      }

      if (versionCode != null) {
        await saveApkMetadata(versionCode);
      }

      if (kDebugMode) {
        print('[OtaDownloadService] APK downloaded successfully to ${apkFile.path} ($length bytes)');
      }

      return apkFile;
    } catch (e) {
      await clearCachedApk();
      if (kDebugMode) {
        print('[OtaDownloadService] Download error: $e');
      }
      rethrow;
    }
  }
}
