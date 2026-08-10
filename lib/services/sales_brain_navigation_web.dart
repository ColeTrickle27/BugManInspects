import 'dart:html' as html;

/// Navigates the top-level browser window to a Sales Brain report handoff
/// URL (item 14 of the production pass). When BugMan Graphs is embedded as
/// an iframe inside Holloman Ops Brain, `window.top` escapes the iframe so
/// the user lands on the full Sales Brain page rather than trying (and
/// failing) to load it inside the small graph iframe; when running
/// standalone, `window.top` is just `window` itself.
void navigateToSalesBrainReport(String url) {
  final top = html.window.top ?? html.window;
  top.location.href = url;
}
