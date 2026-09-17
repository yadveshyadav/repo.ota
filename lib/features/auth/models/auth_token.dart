/// Data model for authentication tokens returned by login API
class AuthToken {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int? expiresIn;

  const AuthToken({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    final access = source['access'] ??
        source['access_token'] ??
        source['token'] ??
        source['key'] ??
        source['jwt'] ??
        source['accessToken'] ??
        json['access'] ??
        json['access_token'] ??
        json['token'] ??
        json['key'] ??
        '';

    final refresh = source['refresh'] ??
        source['refresh_token'] ??
        source['refreshToken'] ??
        json['refresh'] ??
        json['refresh_token'];

    final type = source['token_type'] ?? source['tokenType'] ?? json['token_type'] ?? 'Bearer';
    final expires = (source['expires_in'] ?? source['expiresIn'] ?? json['expires_in']) as int?;

    return AuthToken(
      accessToken: access.toString(),
      refreshToken: refresh?.toString(),
      tokenType: type.toString(),
      expiresIn: expires,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
      };
}
