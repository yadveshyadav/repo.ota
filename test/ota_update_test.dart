import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/core/update/models/ota_update_info.dart';
import 'package:hero_app/core/update/services/ota_update_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OTA Update Metadata Model & Validation Unit Tests', () {
    test('TEST 1: Installed version 4 vs Remote version 5 -> Update Available', () async {
      final mockClient = MockClient((request) async {
        return http.Response('''
        {
          "version_code": 5,
          "version_name": "5.0",
          "apk_url": "https://raw.githubusercontent.com/yadveshyadav/hero.ota/main/Hero.apk",
          "release_notes": "Fix location detection issue"
        }
        ''', 200);
      });

      final service = OtaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(mockInstalledVersionCode: 4, mockInstalledVersionName: '4.0');

      expect(result.isUpdateAvailable, isTrue);
      expect(result.updateInfo?.versionCode, equals(5));
      expect(result.updateInfo?.versionName, equals('5.0'));
      expect(result.updateInfo?.apkUrl, contains('Hero.apk'));
    });

    test('TEST 2: Installed version 5 vs Remote version 5 -> Up To Date', () async {
      final mockClient = MockClient((request) async {
        return http.Response('''
        {
          "version_code": 5,
          "version_name": "5.0",
          "apk_url": "https://raw.githubusercontent.com/yadveshyadav/hero.ota/main/Hero.apk",
          "release_notes": "Latest version"
        }
        ''', 200);
      });

      final service = OtaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(mockInstalledVersionCode: 5, mockInstalledVersionName: '5.0');

      expect(result.isUpdateAvailable, isFalse);
      expect(result.installedVersionCode, equals(5));
    });

    test('TEST 3: Installed version 6 vs Remote version 5 -> No Downgrade Offered', () async {
      final mockClient = MockClient((request) async {
        return http.Response('''
        {
          "version_code": 5,
          "version_name": "5.0",
          "apk_url": "https://raw.githubusercontent.com/yadveshyadav/hero.ota/main/Hero.apk"
        }
        ''', 200);
      });

      final service = OtaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(mockInstalledVersionCode: 6, mockInstalledVersionName: '6.0');

      expect(result.isUpdateAvailable, isFalse);
    });

    test('TEST 4: Malformed JSON -> Friendly error message', () async {
      final mockClient = MockClient((request) async {
        return http.Response('INVALID_JSON_RESPONSE_HTML_CORRUPT', 200);
      });

      final service = OtaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(mockInstalledVersionCode: 4);

      expect(result.isUpdateAvailable, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage, contains('Unable to check for updates'));
    });

    test('TEST 5: Missing version_code -> Rejected gracefully', () {
      final json = {
        'version_name': '5.0',
        'apk_url': 'https://raw.githubusercontent.com/yadveshyadav/hero.ota/main/Hero.apk',
      };

      expect(() => OtaUpdateInfo.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('TEST 6: Invalid APK URL -> Rejected', () {
      final json = {
        'version_code': 5,
        'version_name': '5.0',
        'apk_url': 'invalid_url_without_https',
      };

      expect(() => OtaUpdateInfo.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('TEST 7: HTTP APK URL (non-HTTPS) -> Rejected for security', () {
      final json = {
        'version_code': 5,
        'version_name': '5.0',
        'apk_url': 'http://insecure.site/Hero.apk',
      };

      expect(() => OtaUpdateInfo.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('TEST 8 & 12: Network failure -> Friendly error without blocking app login', () async {
      final mockClient = MockClient((request) async {
        throw Exception('SocketException: Failed host lookup');
      });

      final service = OtaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(mockInstalledVersionCode: 4);

      expect(result.isUpdateAvailable, isFalse);
      expect(result.errorMessage, contains('Unable to connect to the update server'));
    });
  });
}
