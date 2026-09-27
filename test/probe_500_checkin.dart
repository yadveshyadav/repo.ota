import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/core/constants/app_constants.dart';
import 'package:hero_app/services/api/api_client.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();

  test('Probe edge cases causing HTTP 500 on Pramaanu check-in endpoint', () async {
    final client = ApiClient(baseUrl: AppConstants.defaultBaseUrl);

    final loginResp = await client.post(
      '/api/v1/auth/login/',
      body: {'username': '9654673404', 'password': '9654673404'},
      isPublic: true,
    );

    final data = loginResp['data'] as Map<String, dynamic>;
    final token = data['access_token'].toString();
    client.setAuthToken(token);

    print('\n==================================================');
    print('PROBING EDGE CASES FOR HTTP 500 ON PRAMAANU CHECK-IN');
    print('==================================================\n');

    final url = '/api/v1/attendance/check-in/';

    final edgeCases = [
      // 1. Non-existent user_id
      {
        'user_id': '999999999',
        'latitude': 28.413788,
        'longitude': 77.042470,
        'accuracy': 10.0,
      },
      // 2. Alphanumeric user_id string
      {
        'user_id': 'non_existent_abc_123',
        'latitude': 28.413788,
        'longitude': 77.042470,
        'accuracy': 10.0,
      },
      // 3. Null or invalid latitude
      {
        'user_id': '158',
        'latitude': null,
        'longitude': 77.042470,
        'accuracy': 10.0,
      },
      // 4. String type for latitude
      {
        'user_id': '158',
        'latitude': '28.413788',
        'longitude': '77.042470',
        'accuracy': '10.0',
      },
    ];

    for (var i = 0; i < edgeCases.length; i++) {
      try {
        print('Testing Edge Case #${i + 1}: ${edgeCases[i]}');
        final res = await client.post(url, body: edgeCases[i]);
        print('  >>> SUCCESS! Response: $res\n');
      } catch (e) {
        print('  >>> CAUGHT ERROR for Edge Case #${i + 1}: $e\n');
      }
    }
  });
}
