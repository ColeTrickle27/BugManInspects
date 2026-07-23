import '../models/trace_geometry.dart';

const String censusGeocoderUrl =
    'https://geocoding.geo.census.gov/geocoder/locations/onelineaddress';

String northCarolinaGeocodeQuery(String address) {
  final trimmed = address.trim();
  final hasNorthCarolina = RegExp(
    r'(^|[,\s])NC([,\s]|$)|NORTH\s+CAROLINA',
    caseSensitive: false,
  ).hasMatch(trimmed);
  return hasNorthCarolina ? trimmed : '$trimmed, NC';
}

GeoPoint? parseNorthCarolinaCensusMatch(Object? response) {
  if (response is! Map) return null;
  final result = response['result'];
  if (result is! Map) return null;
  final matches = result['addressMatches'];
  if (matches is! List || matches.isEmpty) return null;

  for (final candidate in matches) {
    if (candidate is! Map) continue;
    final matchedAddress = candidate['matchedAddress']?.toString() ?? '';
    final isNorthCarolina = RegExp(
      r',\s*NC(?:,|\s|$)|NORTH\s+CAROLINA',
      caseSensitive: false,
    ).hasMatch(matchedAddress);
    if (!isNorthCarolina) continue;

    final coordinates = candidate['coordinates'];
    if (coordinates is! Map) continue;
    final longitude = _asDouble(coordinates['x']);
    final latitude = _asDouble(coordinates['y']);
    if (latitude != null && longitude != null) {
      return GeoPoint(latitude: latitude, longitude: longitude);
    }
  }
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
