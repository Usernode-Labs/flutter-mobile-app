# Repository Guidelines

## Project Structure & Module Organization
- `lib/core`: routing, theme, DI, errors, config, telemetry.
- `lib/features`: feature-first modules (e.g., `node/`, `wallet/`, `settings/`).
- `lib/gen_l10n`: generated localization files.
- `rust_builder/`: Rust code and flutter_rust_bridge integration.
- `assets/`, `android/`, `ios/`, `web/`, `macos/`, `linux/`, `windows/`.
- `test/`: unit/widget/provider tests. See `README.md` and `ARCHITECTURE.md` for details.

## Build, Test, and Development Commands
- Install deps: `flutter pub get`
- Generate l10n: `flutter gen-l10n`
- FRB codegen: `flutter_rust_bridge_codegen generate` (see `flutter_rust_bridge.yaml`)
- Run app: `flutter run` (use `--dart-define` flags as needed)
- Analyze: `flutter analyze`
- Format check: `dart format --output=none --set-exit-if-changed .`
- Tests: `flutter test` (CI runs format/analyze/tests on PRs)

Examples
- Enable result-based node providers: `flutter run --dart-define=USE_RESULT_PROVIDERS=true`
- Provide Sentry DSN: `flutter run --dart-define=SENTRY_DSN=...`

## Coding Style & Naming Conventions
- Dart/Flutter defaults with `flutter_lints` (see `analysis_options.yaml`).
- Indentation: 2 spaces; line length ~120 (see `.vscode` example in README).
- Naming: files `lower_snake_case.dart`; classes `UpperCamelCase`; members `lowerCamelCase`.
- Providers: suffix with `Provider`; async variants return `AsyncValue<T>`.
- Keep features self-contained (presentation/domain/data) and prefer Riverpod for state.

## Testing Guidelines
- Place tests in `test/` mirroring `lib/` paths; name files `*_test.dart`.
- Use provider overrides and fakes for repositories.
- Favor small, deterministic tests (widgets/providers); add tests when changing logic.
- Run `flutter test` locally; ensure `flutter analyze` passes before PRs.

## Commit & Pull Request Guidelines
- Commits: concise, present tense; prefer Conventional Commits (e.g., `feat:`, `fix:`, `chore:`).
- PRs: clear description, linked issues, screenshots/GIFs for UI, platform notes (iOS/Android), and test updates.
- CI must pass (format/analyze/tests). Avoid unrelated refactors; keep diffs focused.

## Security & Configuration Tips
- Do not commit secrets. Pass config via `--dart-define` (e.g., `APP_ENV`, `API_BASE_URL`, `SENTRY_DSN`).
- If Rust bridge types change, rerun FRB codegen and consider `flutter clean`.
