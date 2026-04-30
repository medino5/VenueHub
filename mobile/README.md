# VenueHub Mobile

Flutter Android client for VenueHub.

## Local Emulator

The app defaults to:

```text
http://10.0.2.2:5000/api
```

Run:

```bash
flutter pub get
flutter run
```

## Release APK With Render API

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-render-service.onrender.com/api
```

APK output:

```text
build/app/outputs/flutter-apk/app-release.apk
```
