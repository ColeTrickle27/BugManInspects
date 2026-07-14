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

## Validation

Before pushing feature work, run:

```sh
flutter analyze
flutter test
flutter build web --release --base-href /BugManInspects/
```
