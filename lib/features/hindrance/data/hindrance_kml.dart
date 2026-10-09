import 'dart:convert';

class HindranceKml {
  static String build({
    required String name,
    required List<Map<String, dynamic>> routePoints,
  }) {
    final coordinates = routePoints
        .map((point) {
          final latitude = (point['latitude'] as num?)?.toDouble();
          final longitude = (point['longitude'] as num?)?.toDouble();
          if (latitude == null ||
              longitude == null ||
              !latitude.isFinite ||
              !longitude.isFinite ||
              latitude < -90 ||
              latitude > 90 ||
              longitude < -180 ||
              longitude > 180) {
            return null;
          }
          return '${longitude.toStringAsFixed(7)},${latitude.toStringAsFixed(7)},0';
        })
        .whereType<String>()
        .toList();
    if (coordinates.length < 2) {
      throw const FormatException(
        'At least two GPS points are required for KML.',
      );
    }
    final safeName = const HtmlEscape().convert(name);
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>$safeName</name>
    <Placemark>
      <name>Captured route</name>
      <LineString><tessellate>1</tessellate><coordinates>${coordinates.join(' ')}</coordinates></LineString>
    </Placemark>
    <Placemark><name>Start</name><Point><coordinates>${coordinates.first}</coordinates></Point></Placemark>
    <Placemark><name>End</name><Point><coordinates>${coordinates.last}</coordinates></Point></Placemark>
  </Document>
</kml>''';
  }

  static List<Map<String, dynamic>> parse(String kml) {
    final match = RegExp(
      r'<coordinates[^>]*>(.*?)</coordinates>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(kml);
    if (match == null) {
      throw const FormatException('The selected KML has no route coordinates.');
    }
    final points = <Map<String, dynamic>>[];
    for (final item in match.group(1)!.trim().split(RegExp(r'\s+'))) {
      final values = item.split(',');
      if (values.length < 2) continue;
      final longitude = double.tryParse(values[0]);
      final latitude = double.tryParse(values[1]);
      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        continue;
      }
      points.add({'latitude': latitude, 'longitude': longitude});
    }
    if (points.length < 2) {
      throw const FormatException(
        'The selected KML needs at least two valid points.',
      );
    }
    return points;
  }
}
