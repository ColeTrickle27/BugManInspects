# BugManInspects / BugMan Graphs

Internal Flutter app for Holloman Exterminators field inspectors.

The app currently focuses on the graph editor workflow:

- Home / Job List
- New Job
- Graph Canvas
- Drawing/editing tools for walls, property lines, shapes, markers, photos, and text

## Production site

BugMan Graphs is served through Cloudflare Pages.

Live URL:

```text
https://graphs.holloman-ext.com/
```

The GitHub Actions workflow in `.github/workflows/deploy-cloudflare.yml`
builds and publishes `build/web` when `main` changes. An approved direct
release uses the same Cloudflare Pages project:

```sh
npx --yes wrangler pages deploy build/web --project-name=bugman-graphs --branch=main
```

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

The Trace workspace is limited to North Carolina locations. It uses the U.S.
Census Geocoding API for address lookup and NC OneMap's latest statewide
orthoimagery for the aerial tracing surface. No API key, cloud account,
billing, or build-time secret is required.

The imagery is an interactive tracing aid only. Graph exports retain the
scaled trace geometry and measurements without copying the aerial tiles.

## Validation

Before pushing feature work, run:

```sh
flutter analyze
flutter test
flutter build web --release
```
