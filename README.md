# BugManInspects / BugMan Graphs

Internal Flutter app for Holloman Exterminators field inspectors.

The app currently focuses on the graph editor workflow:

- Home / Job List
- New Job
- Graph Canvas
- Drawing/editing tools for walls, property lines, shapes, markers, photos, and text

## Hosted preview

GitHub Pages deploys the Flutter Web app from `main`.

Live URL:

```text
https://coletrickle27.github.io/BugManInspects/
```

Every push to `main` runs the GitHub Actions workflow in `.github/workflows/deploy-web.yml`, then publishes `build/web`.

## Local setup

Run the app locally with Flutter:

```sh
flutter pub get
flutter run -d chrome
```

For a browser URL without opening Chrome automatically:

```sh
flutter run -d web-server --web-port 8787 --web-hostname 127.0.0.1
```

Then open:

```text
http://localhost:8787
```

## Satellite trace setup

The Trace workspace uses Google Maps JavaScript and Geocoding. Create a
user-owned Google Cloud project with billing and budget alerts, enable those
two APIs, and create a browser key restricted to these referrers:

```text
http://127.0.0.1:*
http://localhost:*
https://coletrickle27.github.io/BugManInspects/*
```

Do not commit the key. For local development, pass it at build/run time:

```sh
flutter run -d web-server --web-port 8787 --web-hostname 127.0.0.1 --dart-define=GOOGLE_MAPS_API_KEY=YOUR_RESTRICTED_KEY
```

For GitHub Pages, add the same restricted key as the repository Actions
secret `GOOGLE_MAPS_API_KEY`. Without it, the app still builds and the Trace
workspace displays configuration guidance instead of attempting to load a
map.

## Validation

Before pushing feature work, run:

```sh
flutter analyze
flutter test
flutter build web --release --base-href /BugManInspects/
```
