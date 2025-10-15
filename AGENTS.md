# Repository Guidelines (For Agents)

This file guides agents working in this repository. Follow these conventions and paths when reading, modifying, or adding code. Keep diffs small and focused; prefer surgical updates over broad refactors.

## Project Structure
- `lib/core` — routing, theming, DI, errors, config, telemetry utilities.
- `lib/features` — feature-first modules (e.g., `node/`, `wallet/`, `settings/`, `home/`).
- `lib/gen_l10n` — generated localization; do not edit by hand.
- `rust_builder/` — Rust crates and flutter_rust_bridge integration.
- `assets/`, `android/`, `ios/`, `web/`, `macos/`, `linux/`, `windows/` — platform assets.
- `test/` — unit/widget/provider tests. See also `README.md` and `ARCHITECTURE.md`.

Helpful entry points
- `lib/main.dart` — app bootstrap + Sentry + backend init.
- `lib/app/main_app.dart` — shell + bottom navigation.
- `lib/core/routing/app_router.dart` — `go_router` configuration and routes.
- `lib/core/feature_flags.dart` — feature flags and tags, env/assets overrides.
- `lib/core/design/design_tokens.dart` — spacing, radii, icons, animation durations.
- `lib/core/utils/sentry.dart` — Sentry integration helpers.
- Rust backend façade — `lib/features/node/data/repositories/rust_backend_service.dart`.

## Build, Test, and Dev
- Install deps: `flutter pub get`
- Generate l10n: `flutter gen-l10n`
- FRB codegen: `flutter_rust_bridge_codegen generate` (uses `flutter_rust_bridge.yaml`)
- Run app: `flutter run` (supply `--dart-define` as needed)
- Analyze: `flutter analyze`
- Format check: `dart format --output=none --set-exit-if-changed .`
- Tests: `flutter test` (CI runs format/analyze/tests on PRs)

Common flags
- Enable result-based node providers: `--dart-define=USE_RESULT_PROVIDERS=true`
- Feature toggles: `--dart-define=ENABLED_FEATURES=home,wallet,dapps,profile` or `all`
- Disable specific granular tags: `--dart-define=DISABLED_FEATURES=wallet.bridge`
- Sentry DSN: `--dart-define=SENTRY_DSN=...` (omit to disable Sentry)

## Feature Flags
- Top-level features are in `FeatureFlags.ordered`. Use `FeatureFlags.isEnabled(AppFeature.wallet)`.
- Granular keys (tags) via `FeatureFlags.on('wallet.send')` with default-on behavior unless disabled.
- You can also configure `assets/feature_flags.json` with keys `enabled`, `disabled`, and `order`.

## Localization
- Edit ARB files under `lib/l10n/` (e.g., `app_en.arb`).
- Run `flutter gen-l10n` after changes. Generated code lives in `lib/gen_l10n/`.
- Use `AppLocalizations.of(context)` in UI; avoid hard-coded strings in widgets.

## Navigation
- Uses `go_router` with a shell route. Add/adjust routes in `lib/core/routing/app_router.dart`.
- Bottom navigation items derive from `FeatureFlags.ordered`. Keep labels localized.

## UI & Styling
- Reuse shared widgets: `AppAppBar`, `AppDrawer`, `AppActionButton`, etc. under `lib/core/widgets/`.
- Use design tokens from `core/design/design_tokens.dart` for spacing/radius/sizes instead of literals.
- Material 3 theming is configured globally; follow existing typography and component patterns.

## State & Data Flow
- Riverpod is the standard for state/DI. Providers are in feature modules and `core/di/providers.dart`.
- Provider naming: end with `Provider`; async variants expose `AsyncValue<T>` to the UI.
- Keep features self-contained with Presentation/Domain/Data layers.

## Rust Backend (flutter_rust_bridge)
- Rust code and bridge config live in `rust_builder/` with settings in `flutter_rust_bridge.yaml`.
- The Dart façade for FRB is `RustBackendService`; call it from repositories/providers, not directly from UI.
- After changing FRB APIs or Rust types:
  - Regenerate: `flutter_rust_bridge_codegen generate`
  - If builds act up: `flutter clean` may help

### FRB Exposed Methods (Generated)

**General / Build Info** (`lib/src/rust/lib.dart`)
- `buildInfo()` → `BuildInfo` - Get build information

**Account Management** (`lib/src/rust/account.dart`)
- `accountGenerateRandom()` → `AccountExport` - Generate a random account
- `accountFromSeed({phrase, passphrase?, index?})` → `AccountExport` - Create account from seed phrase
- `accountSecretFromSeed({phrase, passphrase?, index?})` → `String` - Get secret key from seed phrase
- `seedPhraseGenerate({wordCount?})` → `List<String>` - Generate BIP39 seed phrase (returns list of words)

**Node Builder** (`lib/src/rust/node/builder.dart`)
- `NodeBuilder({customRngSeed?})` - Create a new node builder
- `build()` → `Node` - Build the node
- `customInitialTime({time})` - Set custom initial time (testing)
- `enableBlockProducer()` - Enable block producer
- `gatherStats()` - Enable statistics gathering
- `httpServer({port})` - Enable HTTP server
- `initialPeersFromUrl({url})` - Load initial peers from URL
- `mempoolAutoinsertInterval({secs})` - Enable auto-insert random transactions
- `p2PMaxPeers({limit})` - Set max P2P peers
- `p2PNoDiscovery()` - Disable P2P discovery
- `p2PSecKey({key})` - Set P2P secret key
- `p2PSeedNode()` - Configure as seed node

**Node Operations** (`lib/src/rust/node.dart`)
- `Node.new({rngSeed, initialState, service, overrideEffects?})` - Create new node
- `rpc()` → `NodeRpcClient` - Get RPC client
- `runForever()` → `Future<void>` - Run node forever (async)
- `runForeverInNewThread()` - Run node in background thread
- `state()` - Get node state
- `store()` - Get store (immutable)
- `storeMut()` - Get store (mutable)

**RPC Methods** (`lib/src/rust/rpc.dart` via `NodeRpcClient`)
- `epochRewards({epoch?, includeWonSlots?})` → `Future<RpcEpochRewardsResp?>` - Get epoch rewards info
- `listBlockchain({limit?, fromTip?})` → `Future<RpcListBlockchainResp?>` - List blockchain blocks
- `listMempool({owner?, limit?, idsOnly?, cursorAfter?})` → `Future<RpcListMempoolResp?>` - List mempool transactions
- `listUtxosByOwner({owner, limit?})` → `Future<RpcListUtxosByOwnerResp?>` - List UTXOs by owner
- `metrics()` → `Future<RpcMetricsResp?>` - Get node metrics
- `status()` → `Future<RpcStatusResp?>` - Get node status (blockchain, mempool, peers)
- `transferFunds({fromPkHash, amount, toPkHash})` → `Future<RpcTransferFundsResp?>` - Transfer funds

**Key Response Types**
- `RpcStatusResp` — blockchain info (best tip, sync status), mempool info (entries, orphans, size), peer info
- `RpcEpochRewardsResp` — epoch rewards, produced/won blocks, earned/expected totals, won slots
- `RpcListBlockchainResp` — block list with details, root/tip hashes, total count
- `RpcListMempoolResp` — transaction entries (inputs/outputs), IDs, counts, pagination cursor
- `RpcListUtxosByOwnerResp` — owned UTXOs with commitments
- `RpcMetricsResp` — mempool reorg statistics and latency metrics
- `RpcTransferFundsResp` — queue status and error (if any)

All FRB bindings are auto-generated by flutter_rust_bridge v2.11.1.

## Testing
- Mirror `lib/` paths under `test/`; name tests `*_test.dart`.
- Prefer provider/widget tests; use provider overrides and fakes for repositories.
- Keep tests deterministic and small. Update or add tests when logic changes.

## Commit & PR Guidelines
- Commits: concise, present tense; prefer Conventional Commits (`feat:`, `fix:`, `chore:`).
- PRs: include description, linked issues, screenshots/GIFs for UI, platform notes, and tests if applicable.
- CI must pass (format/analyze/tests). Avoid unrelated refactors; keep diffs focused.

## Security & Configuration
- Do not commit secrets. Pass config via `--dart-define` (e.g., `APP_ENV`, `API_BASE_URL`, `SENTRY_DSN`).
- Sentry: configured via `lib/core/utils/sentry.dart`; DSN optional. Breadcrumbs still log locally.

## When Adding/Modifying Screens
- Place new screens under `lib/features/<feature>/presentation/`.
- Localize strings, reuse shared components, and respect tokens.
- Wire data via providers; avoid business logic in widgets.

## Agent Checklist (Before You Finish)
- Code formatted and analyzer clean: `dart format ...` and `flutter analyze`.
- Strings localized and l10n generated if needed.
- Feature flags considered; defaults keep UI functional.
- Tests updated/added for logic changes and passing locally.
- Rust bridge regenerated if Rust API changed.
