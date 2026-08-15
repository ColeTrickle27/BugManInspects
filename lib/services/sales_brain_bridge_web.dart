// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const Set<String> _allowedReturnOrigins = <String>{
  'https://ops.holloman-ext.com',
  'http://localhost:8443',
  'http://127.0.0.1:8443',
};

/// Sends only the real R2 graph key back to an allowlisted SalesBrain host.
/// Supports the standalone editor in either an iframe or a controlled new tab.
void notifySalesBrainGraphSaved(String graphKey) {
  final String safeKey = graphKey.trim();
  if (safeKey.isEmpty) return;
  final String? returnOrigin =
      _verifiedReturnOrigin(Uri.base.queryParameters['returnOrigin']);
  if (returnOrigin == null) return;
  final html.WindowBase? target = html.window.parent != html.window
      ? html.window.parent
      : html.window.opener;
  if (target == null) return;
  final String billToNumber = (Uri.base.queryParameters['billTo'] ?? '').trim();
  final String locationNumber =
      (Uri.base.queryParameters['location'] ?? '').trim();
  if (billToNumber.isEmpty || locationNumber.isEmpty) return;
  target.postMessage(
    <String, String>{
      'type': 'bugman-graph:saved',
      'graphKey': safeKey,
      'billToNumber': billToNumber,
      'locationNumber': locationNumber,
    },
    returnOrigin,
  );
}

String? _verifiedReturnOrigin(String? value) {
  if (value == null || value.isEmpty) return null;
  final Uri? uri = Uri.tryParse(value);
  if (uri == null || uri.origin != value) return null;
  if (_allowedReturnOrigins.contains(uri.origin)) return uri.origin;
  // Cloudflare Pages previews stay scoped to Holloman's trusted Pages host.
  if (uri.scheme == 'https' &&
      uri.host.endsWith('.holloman-ops-brain.pages.dev')) {
    return uri.origin;
  }
  return null;
}
