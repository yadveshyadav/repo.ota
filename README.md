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

## Dev, UAT, and Prod Android builds

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

# Run Prod on a connected device (package: com.infocrats.heroapp)
flutter run --flavor prod --dart-define=ILYNC_ENV=prod

# Build a Prod release APK (IlYnc API: https://ilync.tech)
flutter build apk --release --flavor prod --dart-define=ILYNC_ENV=prod
```

APK outputs are `build/app/outputs/flutter-apk/app-dev-release.apk`,
`build/app/outputs/flutter-apk/app-uat-release.apk`, and
`build/app/outputs/flutter-apk/app-prod-release.apk`. UAT and Prod use the
existing `com.infocrats.heroapp` package ID; Dev adds `.dev`. UAT and Prod
therefore replace each other when installed on the same device. Debug builds
use the same commands without `--release`.
