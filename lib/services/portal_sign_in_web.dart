import 'package:web/web.dart' as web;

/// Keep the graph and pending photos alive while the user renews their session.
/// Called directly from the sign-in button so browsers permit the new tab.
void openPortalSignIn(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
