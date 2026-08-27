import 'dart:convert';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

import '../models/trace_geometry.dart';
import 'address_suggestion_service.dart';
import 'address_suggestion_service_stub.dart';

AddressSuggestionService createAddressSuggestionService() =>
    HttpAddressSuggestionService();

class HttpAddressSuggestionService implements AddressSuggestionService {
  HttpAddressSuggestionService({http.Client? client})
      : _client = client ?? (BrowserClient()..withCredentials = true);

  static const _opsBrainOrigin = 'https://ops.holloman-ext.com';
  final http.Client _client;

  String get _apiOrigin => Uri.base.path.startsWith('/bugman-graphs/')
      ? Uri.base.origin
      : _opsBrainOrigin;

  @override
  Future<List<AddressSuggestion>> suggest(
    String query, {
    required String sessionToken,
  }) async {
    final response = await _post(
      '/api/bugman-graphs/address-suggestions',
      {'query': query, 'sessionToken': sessionToken},
    );
    final payload = _decodeResponse(response);
    final suggestions = payload['suggestions'];
    if (suggestions is! List) return const <AddressSuggestion>[];
    return suggestions
        .whereType<Map>()
        .map((value) => _suggestionFromJson(value))
        .whereType<AddressSuggestion>()
        .toList(growable: false);
  }

  @override
  Future<AddressSelection> select(
    AddressSuggestion suggestion, {
    required String sessionToken,
  }) async {
    final response = await _post(
      '/api/bugman-graphs/address-selection',
      {
        'address': suggestion.address,
        'sessionToken': sessionToken,
      },
    );
    final payload = _decodeResponse(response);
    final standardizedAddress =
        payload['standardizedAddress']?.toString().trim();
    final qualityJson = _asMap(payload['quality']);
    if (standardizedAddress == null ||
        standardizedAddress.isEmpty ||
        qualityJson == null) {
      throw const AddressSuggestionServiceException(
        'The selected address could not be read. Please choose it again.',
      );
    }
    final coordinateJson = _asMap(payload['coordinate']);
    final latitude = _asDouble(coordinateJson?['latitude']);
    final longitude = _asDouble(coordinateJson?['longitude']);
    return AddressSelection(
      standardizedAddress: standardizedAddress,
      coordinate: latitude == null || longitude == null
          ? null
          : GeoPoint(latitude: latitude, longitude: longitude),
      quality: AddressQuality(
        geocodeGranularity:
            qualityJson['geocodeGranularity']?.toString() ?? 'OTHER',
        validationGranularity:
            qualityJson['validationGranularity']?.toString() ?? 'OTHER',
        isPropertyLevel: qualityJson['isPropertyLevel'] == true,
        addressComplete: qualityJson['addressComplete'] == true,
        requiresReview: qualityJson['requiresReview'] == true,
        dpvConfirmation: qualityJson['dpvConfirmation']?.toString(),
      ),
    );
  }

  AddressSuggestion? _suggestionFromJson(Map value) {
    final id = value['id']?.toString().trim();
    final address = value['address']?.toString().trim();
    final primaryText = value['primaryText']?.toString().trim();
    if (id == null ||
        id.isEmpty ||
        address == null ||
        address.isEmpty ||
        primaryText == null ||
        primaryText.isEmpty) {
      return null;
    }
    final secondaryText = value['secondaryText']?.toString().trim();
    return AddressSuggestion(
      id: id,
      address: address,
      primaryText: primaryText,
      secondaryText:
          secondaryText == null || secondaryText.isEmpty ? null : secondaryText,
    );
  }

  Future<http.Response> _post(String path, Map<String, String> body) async {
    try {
      return await _client.post(
        Uri.parse('$_apiOrigin$path'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } on http.ClientException {
      throw const AddressSuggestionServiceException(
        'Address suggestions could not be reached. Check that you are signed '
        'in to OpsBrain, then try again.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const AddressSuggestionServiceException(
        'Address search is temporarily unavailable. Please try again.',
      );
    }
    final payload = _asMap(decoded) ?? <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AddressSuggestionServiceException(
        payload['error']?.toString() ??
            'Address search is temporarily unavailable. Please try again.',
      );
    }
    return payload;
  }
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is! Map) return null;
  return value.map((key, value) => MapEntry(key.toString(), value));
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
