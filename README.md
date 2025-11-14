# Usernode Mobile App

Flutter + Rust hybrid client that lets anyone run a lightweight Usernode, manage wallets, monitor block production, and report feedback straight from a phone. The project is optimized for contributors: feature-first structure, Riverpod for state, Rust for core logic, and CI/CD that mirrors production build pipelines.

---

## Contents
1. [At a Glance](#at-a-glance)
2. [Architecture](#architecture)
3. [Repository Map](#repository-map)
4. [Prerequisites](#prerequisites)
5. [Quick Start](#quick-start)
6. [Configuration & Feature Flags](#configuration--feature-flags)
7. [Running & Debugging](#running--debugging)
8. [Testing](#testing)
9. [Rust & flutter_rust_bridge](#rust--flutter_rust_bridge)
10. [Feedback, Telemetry, Security](#feedback-telemetry-security)
11. [CI/CD & Releases](#cicd--releases)
12. [Troubleshooting](#troubleshooting)
13. [Contributing & Support](#contributing--support)

---

## At a Glance
- **What it does:** wallet management (create/import, send/receive, rewards), live node insights (mempool, scheduled slots, produced blocks), dApp surfacing, notifications, and in-app feedback that opens GitHub issues with device context.
- **Tech stack:** Flutter 3.35 (Material 3 UI) + Riverpod, Rust node via `flutter_rust_bridge`, Sentry, Fastlane, GitHub Actions, WorkManager/local notifications, and feature flags backed by env + assets.
- **Why hybrid?** Heavy blockchain logic stays in Rust for parity with validator nodes, while Flutter focuses on UX and multi-platform reach.

---

## Architecture

```mermaid
flowchart LR
    subgraph Flutter
      UI[UI Screens<br/>(lib/features/*/presentation)]
      Providers[Riverpod Providers<br/>(lib/core/providers)]
      Services[Services & Config<br/>(lib/core/services, config)]
    end

    subgraph RustSide[Rust Node (../usernode)]
      RustCrate[usernode crate<br/>crates/usernode]
    end

    UI --> Providers --> Services --> FRB[flutter_rust_bridge bindings<br/>(lib/src/rust)]
    FRB --> RustCrate
    Services -->|HTTP| RemoteAPIs[(Remote APIs<br/>API_BASE_URL)]
    Services -->|Feedback| GitHub[GitHub Issues<br/>via GITHUB_TOKEN]
    Services -->|Telemetry| Sentry[Sentry DSN]
```

Key flows:
- **Feature-first modules:** Each folder in `lib/features/*` owns presentation + domain + data layers.
- **Rust backend:** `RustBackendService` wraps FRB bindings so providers/widgets never touch Rust directly.
- **Config surface:** `AppConfig` + `FeatureFlags` read from `--dart-define` and optional `assets/feature_flags.json`.
- **Feedback pipeline:** `FeedbackRepository` → `GitHubIssueService` uses a scoped PAT to create issues with optional screenshots.

---

## Repository Map

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | Bootstrap, env wiring, Sentry init, backend start |
| `lib/core/main_app.dart` | App shell (navigation, theming, layout) |
| `lib/core/routing/app_router.dart` | `go_router` routes / deep links |
| `lib/core/feature_flags.dart` | Compile-time + asset feature toggles |
| `lib/core/services/github_issue_service.dart` | Feedback → GitHub |
| `lib/core/utils/sentry.dart` | Sentry helpers and breadcrumbs |
| `lib/features/node/*` | Node dashboards, data sources, controllers |
| `lib/features/wallet/*` | Wallet flows, repositories, models |
| `lib/features/feedback/*` | Feedback UI + repository |
| `lib/core/l10n/` | ARB files + generated localizations |
| `lib/src/rust/` | Generated FRB bindings (do not edit manually) |
| `rust_builder/` | Flutter plug-in shell for the Rust crate |
| `scripts/` | Tooling (versioning, cache cleaning, sim builds) |
| `fastlane/` | Release automation for iOS/TestFlight, Android |
| `docs/AGENTS.md` | Contributor playbook (linguistic style, flags) |

---

## Prerequisites

| Tool | Version / Notes |
| --- | --- |
| Flutter | 3.35.x (Dart 3.3+) |
| Rust | Stable toolchain + `cargo` (`rustup target add aarch64-apple-ios` etc. for platforms) |
| Java | 17 (Android builds) |
| Android SDK | API 34+, emulator or device |
| Xcode | 15+ with CocoaPods (`brew install cocoapods`) |
| Ruby/Bundler | Optional (Fastlane automation) |
| Usernode repo | Clone `Usernode-Labs/usernode` adjacent to this repo (default FRB config expects `../usernode`) |

> `rust_builder/README.md` reminds: treat it as glue; the actual blockchain crate lives in the sibling repository.

---

## Quick Start

```bash
# Clone both repos side-by-side
git clone git@github.com:Usernode-Labs/flutter-mobile-app.git
git clone git@github.com:Usernode-Labs/usernode.git

cd flutter-mobile-app

# Install Flutter deps
flutter pub get

# (Optional) Generate localization or FRB bindings
flutter gen-l10n
flutter_rust_bridge_codegen generate

# Run on a device/emulator
flutter run --dart-define=APP_ENV=dev
```

Use `.env` files (CI-friendly) or pass `--dart-define` flags directly. See configuration table below.

---

## Configuration & Feature Flags

| Variable | Description | Default |
| --- | --- | --- |
| `APP_ENV` | Environment label (also logged to Sentry) | `development` |
| `API_BASE_URL` | REST endpoint for remote services | `''` |
| `VERBOSE_LOGGING` | Enables trace-level logs | `false` |
| `GITHUB_TOKEN` | PAT for GitHub issue creation (scope: repo issues) | `''` (feedback disabled) |
| `SENTRY_DSN` | DSN for Sentry; omit in local dev to disable | `''` |
| `SENTRY_ENVIRONMENT` | Sentry environment tag | `development` |
| `SENTRY_TRACES_SAMPLE_RATE` / `SENTRY_PROFILES_SAMPLE_RATE` | Performance + profile sample rates (0–1) | `0.2` / `0.0` |
| `SENTRY_LOG_STATUS_PAYLOAD` | Allow node payload attachments | `true` |
| `USE_RESULT_PROVIDERS` | Switch node providers to `Result<T>` wrappers | `false` |
| `ENABLED_FEATURES` | CSV list or `all` to control nav tabs | `home,wallet,dapps,profile,node` |
| `DISABLED_FEATURES` | CSV list to remove tabs or granular keys | `''` |

Feature overrides via asset:
```json
// assets/feature_flags.json
{
  "enabled": ["home", "wallet", "node"],
  "disabled": ["wallet.send"],
  "order": ["home", "node", "wallet"]
}
```

Load at runtime with `FeatureFlags.loadFromAssetIfAvailable()` (already invoked during bootstrap).

---

## Running & Debugging

| Target | Command |
| --- | --- |
| Android (device/emulator) | `flutter run -d <device>` |
| iOS Simulator | `scripts/build_ios_sim_verbose.sh` or `flutter run -d ios` |
| macOS desktop | `flutter run -d macos` |
| Web/Chrome | `flutter run -d chrome` (dev only; FRB features limited) |

Tips:
- Supply `--dart-define-from-file=.env` to keep secrets out of shell history.
- For node-heavy debugging, enable verbose logging: `--dart-define=VERBOSE_LOGGING=true`.
- Use `FeatureFlags.on('wallet.someKey')` toggles to gate unfinished UI while keeping the rest of the screen live.

---

## Testing

| Command | Description |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | Formatting gate |
| `flutter analyze` | Lints + static analysis |
| `flutter test` | Unit + widget tests |
| `flutter test integration_test` | Integration tests (requires devices/emulators) |

Testing pointers:
- Mirror the `lib/` structure in `test/`.
- Favor Riverpod overrides/fakes; avoid hitting real Rust/HTTP in tests.
- Keep tests deterministic: no network calls, no real timeouts. Mock `DateTime.now`, feature flags, etc.

---

## Rust & flutter_rust_bridge
- Configured via `flutter_rust_bridge.yaml`:
  - `rust_root: ../usernode/crates/usernode`
  - Generated Dart output: `lib/src/rust`
- Workflow when Rust APIs change:
  1. Update `../usernode`.
  2. Run `flutter_rust_bridge_codegen generate`.
  3. Run `flutter pub run build_runner build` if Freezed models changed.
  4. Clean builds (`flutter clean`, `cargo clean`) if the toolchains desync.
- Scripts:
  - `scripts/clean-cargo-cache.sh` clears Rust caches.
  - `scripts/build_ios_sim_verbose.sh` configures clang/rustflags for iOS Simulator builds.

---

## Feedback, Telemetry, Security

- **Feedback:** `FeedbackRepository` relies on `GitHubIssueService`. Provide `--dart-define=GITHUB_TOKEN=ghp_xxx` (scoped to issue creation). Without it, the in-app form surfaces an error.
- **Telemetry:** `SentryUtil.bootstrap` reads DSN/rates from env. Breadcrumbs still log locally even if DSN is empty.
- **Logging:** `LoggingService` integrates with Sentry breadcrumbs/exceptions and respects `VERBOSE_LOGGING` plus per-tag overrides.
- **Secrets:** Never commit keystores (`android/key.properties` is already gitignored). Use GitHub Secrets / CI variables for signing configs, tokens, and provisioning profiles.

---

## CI/CD & Releases

### Pipeline Overview

```mermaid
flowchart TD
    PR[Pull Request] --> Checks[PR Checks Workflow]
    Checks -->|format/analyze/test| Status
    Checks -->|Build Android| Apk[Debug APK]
    Checks -->|Build iOS| Ipa[iOS Debug build]
    main --> BuildDeploy[build-and-deploy.yml]
    develop --> BuildDeploy
    BuildDeploy --> Store[TestFlight / Play Console (Fastlane)]
    Manual[manual-build.yml] --> Store
```

GitHub Actions workflows (`.github/workflows/`):
- `pr-checks.yml`: format, analyze, test, Android/iOS debug builds with `.env` injected from secrets.
- `build-and-deploy.yml`: production & beta releases (Flutter build + Fastlane upload).
- `test.yml`: lightweight unit-test workflow.
- `setup-rust-tools*.yml`: reusable actions that prep Rust toolchains (FRB, usernode clone).
- `daily-standup.yml`: scheduled job for status pings.

### Release Flow
1. Update `pubspec.yaml` (or run `scripts/version_manager.sh bump patch`).
2. Commit changes with release notes.
3. Use Fastlane:
   - `bundle exec fastlane ios release`
   - `bundle exec fastlane android release`
4. Validate store uploads; monitor Sentry for regressions.

Secrets (keystores, Apple creds, PATs, Sentry DSN) are provided through CI and never stored in the repo.

---

## Troubleshooting

| Issue | Fix |
| --- | --- |
| `flutter_rust_bridge` cannot find crate | Ensure `../usernode` exists or pass `RUST_CRATE_DIR`. |
| iOS build fails due to Pods | `cd ios && pod install --repo-update`. |
| GitHub feedback fails (`token not configured`) | Supply `--dart-define=GITHUB_TOKEN=...` or disable feedback feature flag. |
| Analyzer complains about localization | Run `flutter gen-l10n`. |
| Android release signing errors | Keep keystore local, update `android/key.properties`, and set CI secrets (KEYSTORE_PASSWORD, etc.). |
| Rust payload logging too noisy | Set `--dart-define=SENTRY_LOG_STATUS_PAYLOAD=false`. |

---

## Contributing & Support
- Follow `docs/AGENTS.md` for style, localization, and feature-flag expectations.
- Use Conventional Commits (`feat:`, `fix:`, `chore:`) where possible.
- Before opening a PR:
  - Format + analyze + test locally.
  - Ensure FRB bindings and localization files are regenerated if you touched Rust or ARB files.
  - Add/adjust tests for logic changes.
- Questions? Open a GitHub Issue or start a discussion—include platform logs (`LoggingService` output) and env flags you used.

Happy shipping! 🚀
