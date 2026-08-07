import 'dart:html' as html;

/// Sends only the real R2 graph key back to the Sales Brain iframe host.
/// This stays inactive for standalone BugMan Graphs deployments.
void notifySalesBrainGraphSaved(String graphKey) {
  if (graphKey.trim().isEmpty || !Uri.base.path.startsWith('/bugman-graphs/')) {
    return;
  }
  if (html.window.parent == html.window) return;
  html.window.parent.postMessage(
    <String, String>{'type': 'bugman-graph:saved', 'graphKey': graphKey},
    Uri.base.origin,
  );
}
