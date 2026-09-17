/// Strongly-typed model representing remote OTA update metadata
class OtaUpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String releaseNotes;

  const OtaUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.releaseNotes = '',
  });

  /// Factory parser with strict field validation according to Project Rule 10
  factory OtaUpdateInfo.fromJson(Map<String, dynamic> json) {
    final rawCode = json['version_code'] ?? json['versionCode'];
    if (rawCode == null) {
      throw FormatException('Missing required field: version_code');
    }
    final code = rawCode is num ? rawCode.toInt() : (int.tryParse(rawCode.toString()) ?? 0);
    if (code <= 0) {
      throw FormatException('Invalid version_code: $rawCode (must be > 0)');
    }

    final name = (json['version_name'] ?? json['versionName'])?.toString().trim() ?? '';
    if (name.isEmpty) {
      throw FormatException('Missing or empty required field: version_name');
    }

    final url = (json['apk_url'] ?? json['apkUrl'])?.toString().trim() ?? '';
    if (url.isEmpty || !url.toLowerCase().startsWith('https://')) {
      throw FormatException('Invalid or non-HTTPS apk_url: $url');
    }

    final notes = (json['release_notes'] ?? json['releaseNotes'])?.toString() ?? '';

    return OtaUpdateInfo(
      versionCode: code,
      versionName: name,
      apkUrl: url,
      releaseNotes: notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'version_code': versionCode,
        'version_name': versionName,
        'apk_url': apkUrl,
        'release_notes': releaseNotes,
      };
}
