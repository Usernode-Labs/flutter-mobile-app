# Running and Testing

## App

Run with defaults (no Sentry, AsyncNotifier providers):

```
flutter run
```

Enable Node Result-based providers in NodeStatusScreen (mempool + scheduled slots):

```
flutter run --dart-define=USE_RESULT_PROVIDERS=true
```

Provide Sentry DSN (optional):

```
flutter run --dart-define=SENTRY_DSN=your_sentry_dsn
```

Environment/config values:

```
--dart-define=APP_ENV=staging
--dart-define=API_BASE_URL=https://api.example.com
--dart-define=VERBOSE_LOGGING=true
```

## Setup

1. Clone Repository

```
git clone https://github.com/Usernode-Labs/usernode
cd flutter-mobile-app
```

2. Install Dependencies

```
flutter pub get
```

3. Generate Localization Files

```
flutter gen-l10n
```

4. Install and run flutter_rust_bridge_codegen

```
cargo install --git https://github.com/Usernode-Labs/flutter_rust_bridge flutter_rust_bridge_codegen
flutter_rust_bridge_codegen generate
```

5. Run the Application

```
# Debug mode: select device/emulator when prompted
flutter run

# Specific platforms
flutter run -d android
flutter run -d ios
```

## Theme

- Change ThemeMode in `/settings` (System/Light/Dark), or
- Use the quick toggle (sun icon) on Node Status to cycle modes; the choice persists.

## Tests

Run all tests:

```
flutter test
```

CI workflow (GitHub Actions) runs format check, analyze, and tests on pushes/PRs.
