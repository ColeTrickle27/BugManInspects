import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

import '../models/customer_file.dart';
import 'customer_files_service.dart';
import 'customer_identity_adapter.dart';
import 'bugman_portal_service.dart';

CustomerFilesService createOpsBrainCustomerFilesService() =>
    HttpCustomerFilesService();

/// Real HTTP implementation of [CustomerFilesService], calling Ops Brain's
/// Cloudflare Pages Functions API directly -- the same authenticated
/// session and origin-detection rules used by [HttpBugManPortalService] for
/// graph save/upload/load, so this reuses the same trusted-origin allowlist
/// rather than inventing a second one.
class HttpCustomerFilesService implements CustomerFilesService {
  static const _opsBrainOrigin = 'https://ops.holloman-ext.com';
  static const _cloudflareHosts = {
    'graphs.holloman-ext.com',
    'bugman-graphs.pages.dev',
  };

  late final BrowserClient _client = BrowserClient()..withCredentials = true;

  String get _apiOrigin => Uri.base.path.startsWith('/bugman-graphs/')
      ? Uri.base.origin
      : _opsBrainOrigin;

  @override
  bool get isAvailable =>
      Uri.base.path.startsWith('/bugman-graphs/') ||
      _cloudflareHosts.contains(Uri.base.host);

  @override
  Future<List<CustomerSearchResult>> searchCustomers(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final uri = Uri.parse('$_apiOrigin/api/customer-identity/search')
        .replace(queryParameters: {'q': trimmed});
    final payload = await _get(uri);
    final results = payload['results'];
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .map(canonicalCustomerSearchResult)
        .whereType<CustomerSearchResult>()
        .toList();
  }

  @override
  Future<List<CustomerLocation>> getLocations(String billToNumber) async {
    final uri = Uri.parse('$_apiOrigin/api/accounts')
        .replace(queryParameters: {'billTo': billToNumber});
    final payload = await _get(uri);
    final accounts = payload['accounts'];
    if (accounts is! List) return const [];
    return accounts.whereType<Map>().map((row) => _rowToLocation(row)).toList();
  }

  @override
  Future<CustomerLocation?> getLocation(
    String billToNumber,
    String locationNumber,
  ) async {
    if (billToNumber.trim().isEmpty || locationNumber.trim().isEmpty) {
      return null;
    }
    for (final result in await searchCustomers(locationNumber)) {
      if (result.location.billToNumber == billToNumber.trim() &&
          result.location.locationNumber == locationNumber.trim()) {
        return result.location;
      }
    }
    return null;
  }

  CustomerLocation _rowToLocation(Map row) {
    String field(String key) => (row[key]?.toString() ?? '').trim();
    return CustomerLocation(
      billToNumber: field('billToNumber'),
      billToName: field('billToName'),
      locationNumber: field('locationNumber'),
      locationName: field('locationName'),
      locationAddress:
          field('locationAddress').isEmpty ? null : field('locationAddress'),
      lastModified:
          field('lastModified').isEmpty ? null : field('lastModified'),
      prefix: field('prefix').isEmpty ? null : field('prefix'),
    );
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await _client.get(uri);
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw PortalAuthenticationException('$_apiOrigin/');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
            ? decoded.map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{};
    if (response.statusCode == 404) {
      throw OpsBrainNotFoundException(
        payload['error']?.toString() ?? 'Not found.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        payload['error']?.toString() ??
            'Holloman Ops Brain request failed (${response.statusCode}).',
      );
    }
    return payload;
  }
}

/// Thrown internally when Ops Brain reports a 404 for a Bill-To/Location
/// lookup. Callers see this collapsed to `null` from [getLocation] --
/// "not found" is an expected, non-exceptional outcome for identifiers
/// that don't exist in Ops Brain yet.
class OpsBrainNotFoundException implements Exception {
  const OpsBrainNotFoundException(this.message);
  final String message;
  @override
  String toString() => message;
}
