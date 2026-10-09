import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../features/auth/services/auth_storage_service.dart';

/// Centralized Production ApiClient for HERO APP backend REST APIs.
class ApiClient {
  final String baseUrl;
  final http.Client _client;
  String? _authToken;

  ApiClient({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: AppConstants.defaultBaseUrl,
            ),
        _client = client ?? http.Client();

  String? get authToken => _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Uri _buildUri(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return Uri.parse(endpoint);
    }
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    var cleanEp = endpoint.startsWith('/') ? endpoint : '/$endpoint';

    // Django APPEND_SLASH safety: ensure endpoints without query params end with trailing slash '/'
    // to prevent 301 Moved Permanently redirects that convert POST -> GET and drop POST body.
    if (!cleanEp.contains('?') && !cleanEp.endsWith('/')) {
      cleanEp = '$cleanEp/';
    }

    return Uri.parse('$cleanBase$cleanEp');
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = (_authToken != null && _authToken!.isNotEmpty)
        ? _authToken!
        : (AuthStorageService().accessToken ?? '');

    if (token.isNotEmpty) {
      headers['Authorization'] = token.startsWith('Bearer ')
          ? token
          : 'Bearer $token';
    } else {
      const envToken = String.fromEnvironment('API_TOKEN');
      if (envToken.isNotEmpty) {
        headers['Authorization'] = envToken.startsWith('Bearer ')
            ? envToken
            : 'Bearer $envToken';
      }
      const envApiKey = String.fromEnvironment('API_KEY');
      if (envApiKey.isNotEmpty) {
        headers['x-api-key'] = envApiKey;
      }
    }
    return headers;
  }

  Future<dynamic> get(String endpoint, {int redirectCount = 0}) async {
    if (redirectCount > 3) {
      throw Exception('Too many HTTP redirects (301/302/307/308) while contacting server.');
    }
    final uri = _buildUri(endpoint);
    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          if (kDebugMode) {
            print('[ApiClient] GET [301 Redirect] from $uri to $redirectUrl');
          }
          return await get(redirectUrl, redirectCount: redirectCount + 1);
        }
      }

      return _processResponse(response);
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Server connection timed out. Please check your network or try again.');
      }
      rethrow;
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool isPublic = false,
    int redirectCount = 0,
  }) async {
    if (redirectCount > 3) {
      throw Exception('Too many HTTP redirects (301/302/307/308) while contacting server.');
    }
    final uri = _buildUri(endpoint);
    try {
      final reqHeaders = Map<String, String>.from(_headers);
      if (isPublic || endpoint.contains('/auth/login') || endpoint.contains('/auth/register')) {
        reqHeaders.remove('Authorization');
      }
      final response = await _client
          .post(
            uri,
            headers: reqHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          if (kDebugMode) {
            print('[ApiClient] POST [301 Redirect] from $uri to $redirectUrl');
          }
          return await post(
            redirectUrl,
            body: body,
            isPublic: isPublic,
            redirectCount: redirectCount + 1,
          );
        }
      }

      return _processResponse(response);
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Server connection timed out. Please check your network or try again.');
      }
      rethrow;
    }
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    int redirectCount = 0,
  }) async {
    if (redirectCount > 3) {
      throw Exception('Too many HTTP redirects (301/302/307/308) while contacting server.');
    }
    final uri = _buildUri(endpoint);
    try {
      final reqHeaders = Map<String, String>.from(_headers);
      final response = await _client
          .put(
            uri,
            headers: reqHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          if (kDebugMode) {
            print('[ApiClient] PUT [301 Redirect] from $uri to $redirectUrl');
          }
          return await put(
            redirectUrl,
            body: body,
            redirectCount: redirectCount + 1,
          );
        }
      }

      return _processResponse(response);
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Server connection timed out. Please check your network or try again.');
      }
      rethrow;
    }
  }

  /// Upload raw byte payload (e.g. JPEG image) to presigned uploadUrl
  Future<http.Response> putRawBytes(
    String uploadUrl,
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final uri = Uri.parse(uploadUrl);
    final headers = <String, String>{
      'Content-Type': contentType,
    };
    try {
      if (kDebugMode) {
        // Presigned URLs contain temporary credentials; never write them to logs.
        print('[ApiClient] Uploading ${bytes.length} bytes via presigned PUT.');
      }
      final response = await _client
          .put(uri, headers: headers, body: bytes)
          // Video evidence can be large and the tablet may be on a slow mobile
          // connection. Keep the signed URL alive for a realistic upload window.
          .timeout(const Duration(minutes: 2));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          print('[ApiClient] Raw bytes PUT failed [${response.statusCode}]: ${response.body}');
        }
        throw Exception('Failed to upload media [${response.statusCode}]: ${response.reasonPhrase}');
      }
      return response;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Media upload timed out. Please check your connection and try again.');
      }
      rethrow;
    }
  }

  Future<dynamic> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    http.MultipartFile? file,
    List<http.MultipartFile>? files,
    int redirectCount = 0,
  }) async {
    if (redirectCount > 3) {
      throw Exception('Too many HTTP redirects (301/302/307/308) during file upload.');
    }
    final uri = _buildUri(endpoint);
    try {
      final request = http.MultipartRequest('POST', uri);

      final authHeaders = Map<String, String>.from(_headers);
      authHeaders.remove('Content-Type');
      request.headers.addAll(authHeaders);

      request.fields.addAll(fields);

      if (file != null) {
        request.files.add(file);
      }
      if (files != null && files.isNotEmpty) {
        request.files.addAll(files);
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          if (kDebugMode) {
            print('[ApiClient] Multipart POST [301 Redirect] from $uri to $redirectUrl');
          }
          return await postMultipart(
            redirectUrl,
            fields: fields,
            file: file,
            files: files,
            redirectCount: redirectCount + 1,
          );
        }
      }

      return _processResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic decodedBody;
    if (response.body.isNotEmpty) {
      try {
        decodedBody = jsonDecode(response.body);
      } catch (_) {
        decodedBody = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    } else {
      String errorMessage = response.reasonPhrase ?? 'Server Error';
      if (decodedBody is Map<String, dynamic>) {
        if (decodedBody.containsKey('detail') && decodedBody['detail'] != null) {
          errorMessage = decodedBody['detail'].toString();
        } else if (decodedBody.containsKey('message') && decodedBody['message'] != null) {
          errorMessage = decodedBody['message'].toString();
        } else if (decodedBody.containsKey('error') && decodedBody['error'] != null) {
          errorMessage = decodedBody['error'].toString();
        } else {
          final fieldErrors = <String>[];
          decodedBody.forEach((key, val) {
            if (val is List) {
              fieldErrors.add('$key: ${val.join(", ")}');
            } else if (val is Map) {
              fieldErrors.add('$key: ${val.toString()}');
            } else if (val != null) {
              fieldErrors.add('$key: $val');
            }
          });
          if (fieldErrors.isNotEmpty) {
            errorMessage = fieldErrors.join(' | ');
          }
        }
      }

      if (kDebugMode) {
        print('[ApiClient] API Error [${response.statusCode}] on ${response.request?.url}: $errorMessage');
      }

      if (response.statusCode == 401) {
        throw Exception('Unauthorized [401]: Session expired or invalid token.');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden [403]: $errorMessage');
      } else if (response.statusCode == 404) {
        throw Exception('Not Found [404]: $errorMessage');
      } else if (response.statusCode == 409) {
        throw Exception('Conflict [409]: $errorMessage');
      } else if (response.statusCode == 408) {
        throw Exception('Timeout [408]: Server request timed out.');
      } else if (response.statusCode >= 500) {
        throw Exception('Server Error [${response.statusCode}]: $errorMessage');
      }
      throw Exception('API Error [${response.statusCode}]: $errorMessage');
    }
  }
}
