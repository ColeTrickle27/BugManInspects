# BugMan Graphs

Internal Flutter app for Holloman Exterminators field inspectors.

This first version is a UI shell for the MVP workflow:

- Home / Job List
- New Job
- Graph Canvas
- Basic canvas toolbar placeholders

## Local setup

Flutter was not available in this Codex environment, so the native platform folders have not been generated yet.

Once Flutter is installed locally, run:

```sh
flutter create . --platforms=ios,android
flutter pub get
flutter run
```

The source code for the first app shell lives in `lib/`.
