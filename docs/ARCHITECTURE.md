# Architecture Overview

This app follows a feature-first, layered architecture to keep code easy to navigate, test, and evolve.

Layers (by responsibility):

1. Presentation
   - Widgets, screens, and controllers/providers.
   - UI reads data via domain interfaces (repositories/use cases).
   - No direct calls to platform/rust APIs.

2. Domain
   - Pure Dart: entities, value objects, repository interfaces, and use cases.
   - No Flutter imports, no IO, no Sentry/logging.
   - Defines the contracts that the Data layer implements.

3. Data
   - Implements domain repositories using datasources (Rust via FRB, storage, network).
   - Maps DTOs ⇄ Domain entities.
   - May depend on Flutter plugins and platform bridges.

4. Core (cross-cutting)
   - Telemetry (Sentry), logging, theming, design tokens, feature flags, routing, DI.
   - No dependency on features.

## Dependency Rules

- Presentation → Domain and Core.
- Data → Domain (interfaces/entities) and Core.
- Domain → SDK only (no Flutter, no Core).
- Core → May depend on Flutter; must not depend on features.

Enforcement guidelines:
- Domain files never import `package:flutter/*`.
- Data never import from `presentation/*`.
- UI prefers imports from `features/<feature>/domain/...`.

## Current Layout (examples)

- `features/wallet/domain/...`: Wallet domain entities and repository interfaces.
- `features/wallet/data/...`: DTOs, mappers, repository implementations.
- `features/node/domain/...`: Node domain entities and repository interfaces.
- `features/node/data/...`: Rust bridge façade and repository implementation.
- `core/...`: Sentry, logging, feature flags, theme, errors.

## Implemented Boundaries (Phase 1)

- Wallet
  - `features/wallet/domain/entities/{transaction.dart,wallet_balance.dart}`
  - `features/wallet/domain/repositories/wallet_repository.dart`
  - `features/wallet/data/repositories/wallet_repository_impl.dart` (wraps existing `WalletService`)
  - `features/wallet/data/mappers/wallet_mappers.dart` DTO→Domain

- Node
  - `features/node/domain/entities/node_status.dart`
  - `features/node/domain/repositories/node_repository.dart`
  - `features/node/data/repositories/node_repository_impl.dart` (wraps `RustBackendService`)

## What's Implemented Now

- Provider‑driven Node UI (raw status, sync status, mempool, blockchain, epoch rewards)
- Optional Result‑based providers for Node (toggle with `USE_RESULT_PROVIDERS=true`)
- Wallet provider and UTXO provider
- go_router with ShellRoute tabs, guards, and `/settings`
- Theme persistence (Settings + quick app bar toggles)
- Lifecycle breadcrumbs + config via `--dart-define`
- CI with format/analyze/tests

## State Management

The app uses **Riverpod** for all state management with a singleton RustBackendService as the central data hub:
- 25+ providers organized by feature (node, wallet, rewards, core)
- Centralized RustBackendService for all Rust backend communication via Flutter Rust Bridge
- Auto-refresh mechanisms for real-time data updates
- Comprehensive error handling with defensive PanicException catching
- Complete Sentry logging and telemetry

**📖 See [STATE_MANAGEMENT.md](./STATE_MANAGEMENT.md)** for complete documentation including:
- Complete provider inventory with all 25 providers
- RustBackendService architecture, lifecycle, and all RPC methods
- Data flow diagrams with detailed ASCII visualizations
- Code examples for common patterns (watch, read, refresh, error handling)
- Best practices for provider organization and performance
- Troubleshooting guide for common issues

## Adding a New Feature

1. Create folders:
   - `features/<feature>/domain/{entities,repositories,usecases}`
   - `features/<feature>/data/{datasources,repositories,mappers,models}`
   - `features/<feature>/presentation/{screens,widgets,controllers}`

2. Design Domain
   - Define minimal entities (UI-agnostic) and repository interfaces.
   - Prefer immutable classes and narrow interfaces.

3. Implement Data
   - Create datasources (e.g., FRB, HTTP, storage) and repository implementations.
   - Write mapping extensions/functions for DTO ⇄ Domain.

4. Wire Presentation
   - Inject repositories via DI/providers.
   - Keep widgets thin; business logic in controllers/providers.

## Error Handling

- Domain returns typed errors (see `core/errors/app_error.dart`) or a `Result` abstraction.
- Data maps plugin/bridge exceptions to `AppError` types.
- Presentation decides how to render errors (snackbar, empty state, etc.).

### Result type

Use `core/result.dart` for fallible operations when you want to avoid exceptions across boundaries.

- `Ok<T>(value)` for success, `Err<T>(AppError)` for failure.
- Providers can return `Result<T>` or unwrap with sensible defaults.
- Migrate incrementally: you can offer both `Future<T>` and `Future<Result<T>>` until callers switch over.

## Startup

- `main.dart` renders UI immediately and performs bootstrap asynchronously.
- Backend init/start is encapsulated behind repositories (Node) and should not be called from Widgets directly.

## Configuration

- Central config at `core/config/app_config.dart` reads from `--dart-define` values:
  - `APP_ENV` (default: `development`)
  - `API_BASE_URL` (default: empty)
  - `VERBOSE_LOGGING` (default: `false`)
- Access via `AppConfig.instance`.
- Sentry settings separately read their own `--dart-define`s inside `SentryUtil`.

## Feature Flags and Toggles

- Result providers for Node data are available behind a `--dart-define` toggle:
  - `USE_RESULT_PROVIDERS=true` → NodeStatusScreen reads result-based providers for mempool and scheduled slots.
  - Default (false) uses AsyncNotifier providers. This avoids unexpected FRB calls in tests/CI.
- Theme Mode is persisted via `themeModeProvider` and can be changed in `/settings` or via the quick toggle on the Node screen.

## Navigation

- Centralized router using `go_router` in `core/routing/app_router.dart` via `appRouterProvider`.
- Routes: `/splash`, `/onboarding`, `/main` (tabs handled inside MainApp).
- Guards: users without accounts cannot access `/main`; users with accounts are redirected away from `/onboarding`.
- Sentry navigator observers attached via GoRouter `observers`.
- Settings route `/settings` allows users to change ThemeMode and view Build Info.
- ShellRoute wraps MainApp to support tabbed navigation and path-based tab selection.
- Quick theme toggles are available on Node Status, Home, and Profile app bars for convenience.
