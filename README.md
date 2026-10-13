# hero_app

HDD hero fibre

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Dev and UAT Android builds

Build from the repository root with Flutter. Always pair the Android flavor
with the matching `ILYNC_ENV` define so the app label, package, and IlYnc API
environment agree.

```powershell
# Run Dev on a connected device (package: com.infocrats.heroapp.dev)
flutter run --flavor dev --dart-define=ILYNC_ENV=dev

# Build a Dev release APK
flutter build apk --release --flavor dev --dart-define=ILYNC_ENV=dev

# Run UAT on a connected device (package: com.infocrats.heroapp)
flutter run --flavor uat --dart-define=ILYNC_ENV=uat

# Build a UAT release APK
flutter build apk --release --flavor uat --dart-define=ILYNC_ENV=uat
```

APK outputs are `build/app/outputs/flutter-apk/app-dev-release.apk` and
`build/app/outputs/flutter-apk/app-uat-release.apk`. The UAT flavor retains the
existing `com.infocrats.heroapp` package ID; Dev adds `.dev`, so both can be
installed together. Debug builds use the same commands without `--release`.
