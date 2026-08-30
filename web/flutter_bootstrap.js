{{flutter_js}}
{{flutter_build_config}}

// Keep the production editor from reusing a prior release's stable
// main.dart.js URL. Flutter's generated service worker and the browser cache
// can otherwise keep an older Graphs build alive for hours after deployment.
const bugManRelease = '20260830-trace-reopen';
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath = `${build.mainJsPath}?release=${bugManRelease}`;
  }
}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
    serviceWorkerUrl: `flutter_service_worker.js?release=${bugManRelease}`,
  },
});
