# Usernode App Architecture

## Overview

This project follows a **feature-oriented clean architecture** designed to support both first-party features and third-party dApps in a scalable, maintainable structure.

The app uses a layered approach with clear boundaries to keep code easy to navigate, test, and evolve.

## Directory Structure

```
lib/
├── app/                           # App-level configuration
│   └── main_app.dart             # Main navigation container
│
├── core/                          # Shared infrastructure (first-party only)
│   ├── blockchain/               # Blockchain/Rust FFI wrappers
│   ├── constants/                # App-wide constants
│   ├── routing/                  # Navigation utilities
│   ├── storage/                  # Storage abstractions
│   ├── theme/                    # Material 3 theming
│   ├── utils/                    # Logging, Sentry, utilities
│   └── widgets/                  # Shared UI components
│
├── features/                      # First-party features (core app)
│   ├── wallet/
│   │   ├── data/
│   │   │   ├── models/          # DTOs, data models
│   │   │   ├── repositories/    # Data repositories
│   │   │   └── datasources/     # External data sources
│   │   ├── domain/
│   │   │   ├── entities/        # Business entities
│   │   │   └── usecases/        # Business logic
│   │   └── presentation/
│   │       ├── screens/         # UI screens
│   │       └── widgets/         # Feature-specific widgets
│   │
│   ├── node/                     # Node management
│   ├── home/                     # Home dashboard
│   ├── onboarding/               # User onboarding
│   ├── splash/                   # Splash screen
│   └── rewards/                  # Rewards system
│
├── dapps/                         # Third-party dApps (isolated)
│   ├── README.md                 # Integration guide for developers
│   └── _example_dapp/            # Example dApp template
│       ├── dapp_manifest.yaml   # dApp metadata
│       ├── data/
│       ├── domain/
│       └── presentation/
│
├── gen_l10n/                      # Generated localization files
├── l10n/                          # Localization source files
├── src/                           # Generated code (Rust FFI)
│   └── rust/                     # Flutter Rust Bridge generated
│
└── main.dart                      # App entry point
```

## Architecture Layers

### 1. Presentation Layer
- **Widgets**, **screens**, and **controllers/providers**
- UI reads data via domain interfaces (repositories/use cases)
- No direct calls to platform/rust APIs
- Keeps widgets thin; business logic in controllers/providers

### 2. Domain Layer
- **Entities**: Pure business objects (UI-agnostic)
- **Usecases**: Business logic operations
- **Repository Interfaces**: Contracts that Data layer implements
- Pure Dart: no Flutter imports, no IO, no Sentry/logging

### 3. Data Layer
- **Models**: Data transfer objects, API responses
- **Repositories**: Data access logic implementations
- **Datasources**: External data sources (APIs, databases, secure storage)
- Implements domain repositories using datasources (Rust via FRB, storage, network)
- Maps DTOs ⇄ Domain entities
- May depend on Flutter plugins and platform bridges

### 4. Core (Cross-Cutting)
- Telemetry (Sentry), logging, theming, design tokens, feature flags, routing, DI
- No dependency on features
- Shared infrastructure for first-party features only

## Dependency Rules

### ✅ Allowed Dependencies

**Presentation Layer:**
- ✅ Domain (interfaces/entities)
- ✅ Core

**Data Layer:**
- ✅ Domain (interfaces/entities)
- ✅ Core
- ✅ Flutter plugins and platform bridges

**Domain Layer:**
- ✅ SDK only (Pure Dart)

**Core:**
- ✅ May depend on Flutter
- ❌ Must not depend on features

**Features can import from:**
- ✅ `core/*` (shared infrastructure)
- ✅ Same feature's own directories
- ✅ `gen_l10n/*` (localization)
- ✅ `src/rust/*` (Rust FFI bindings)

**dApps can import from:**
- ✅ `core/*` only
- ✅ Same dApp's own directories

### ❌ Prohibited Dependencies

**Features MUST NOT import from:**
- ❌ Other features (`features/other_feature/*`)
- ❌ dApps (`dapps/*`)

**dApps MUST NOT import from:**
- ❌ Features (`features/*`)
- ❌ Other dApps (`dapps/other_dapp/*`)

**Core MUST NOT import from:**
- ❌ Features
- ❌ dApps

**Domain files:**
- ❌ Never import `package:flutter/*`

**Data layer:**
- ❌ Never import from `presentation/*`

### Enforcement Guidelines

- Domain files never import `package:flutter/*`
- Data never import from `presentation/*`
- UI prefers imports from `features/<feature>/domain/...`

## Feature Structure Template

```
features/your_feature/
├── data/
│   ├── models/
│   │   └── your_model.dart
│   ├── repositories/
│   │   └── your_repository.dart
│   ├── datasources/
│   │   └── your_datasource.dart
│   └── mappers/
│       └── your_mappers.dart
├── domain/
│   ├── entities/
│   │   └── your_entity.dart
│   ├── repositories/
│   │   └── your_repository.dart
│   └── usecases/
│       └── your_usecase.dart
└── presentation/
    ├── screens/
    │   └── your_screen.dart
    ├── widgets/
    │   └── your_widget.dart
    └── controllers/
        └── your_controller.dart
```

## Import Conventions

Always use absolute imports:

```dart
// ✅ Good
import 'package:crypto_mobile_app/core/theme/theme.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';

// ❌ Bad
import '../../../core/theme/theme.dart';
import '../../data/models/account.dart';
```

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

### Current Implementation

- Provider-driven Node UI (raw status, sync status, mempool, blockchain, epoch rewards)
- Optional Result-based providers for Node (toggle with `USE_RESULT_PROVIDERS=true`)
- Wallet provider and UTXO provider
- go_router with ShellRoute tabs, guards, and `/settings`
- Theme persistence (Settings + quick app bar toggles)
- Lifecycle breadcrumbs + config via `--dart-define`
- CI with format/analyze/tests

## Implemented Boundaries (Phase 1)

**Wallet**
- `features/wallet/domain/entities/{transaction.dart,wallet_balance.dart}`
- `features/wallet/domain/repositories/wallet_repository.dart`
- `features/wallet/data/repositories/wallet_repository_impl.dart` (wraps existing `WalletService`)
- `features/wallet/data/mappers/wallet_mappers.dart` DTO→Domain

**Node**
- `features/node/domain/entities/node_status.dart`
- `features/node/domain/repositories/node_repository.dart`
- `features/node/data/repositories/node_repository_impl.dart` (wraps `RustBackendService`)

## Navigation

- Centralized router using `go_router` in `core/routing/app_router.dart` via `appRouterProvider`
- Routes: `/splash`, `/onboarding`, `/main` (tabs handled inside MainApp)
- Guards: users without accounts cannot access `/main`; users with accounts are redirected away from `/onboarding`
- Sentry navigator observers attached via GoRouter `observers`
- Settings route `/settings` allows users to change ThemeMode and view Build Info
- ShellRoute wraps MainApp to support tabbed navigation and path-based tab selection
- Quick theme toggles are available on Node Status, Home, and Profile app bars for convenience

## Configuration

Central config at `core/config/app_config.dart` reads from `--dart-define` values:
- `APP_ENV` (default: `development`)
- `API_BASE_URL` (default: empty)
- `VERBOSE_LOGGING` (default: `false`)

Access via `AppConfig.instance`.

Sentry settings separately read their own `--dart-define`s inside `SentryUtil`.

## Feature Flags and Toggles

- Result providers for Node data are available behind a `--dart-define` toggle:
  - `USE_RESULT_PROVIDERS=true` → NodeStatusScreen reads result-based providers for mempool and scheduled slots
  - Default (false) uses AsyncNotifier providers. This avoids unexpected FRB calls in tests/CI
- Theme Mode is persisted via `themeModeProvider` and can be changed in `/settings` or via the quick toggle on the Node screen

## Error Handling

- Domain returns typed errors (see `core/errors/app_error.dart`) or a `Result` abstraction
- Data maps plugin/bridge exceptions to `AppError` types
- Presentation decides how to render errors (snackbar, empty state, etc.)

### Result Type

Use `core/result.dart` for fallible operations when you want to avoid exceptions across boundaries.

- `Ok<T>(value)` for success, `Err<T>(AppError)` for failure
- Providers can return `Result<T>` or unwrap with sensible defaults
- Migrate incrementally: you can offer both `Future<T>` and `Future<Result<T>>` until callers switch over

## Startup

- `main.dart` renders UI immediately and performs bootstrap asynchronously
- Backend init/start is encapsulated behind repositories (Node) and should not be called from Widgets directly

## Adding a New Feature

1. **Create folders**:
   - `features/<feature>/domain/{entities,repositories,usecases}`
   - `features/<feature>/data/{datasources,repositories,mappers,models}`
   - `features/<feature>/presentation/{screens,widgets,controllers}`

2. **Design Domain**:
   - Define minimal entities (UI-agnostic) and repository interfaces
   - Prefer immutable classes and narrow interfaces

3. **Implement Data**:
   - Create datasources (e.g., FRB, HTTP, storage) and repository implementations
   - Write mapping extensions/functions for DTO ⇄ Domain

4. **Wire Presentation**:
   - Inject repositories via DI/providers
   - Keep widgets thin; business logic in controllers/providers

5. **Register Navigation** (if needed):
   - Add screens to routing configuration
   - Update navigation guards if required

6. **Use only `core/*` for shared functionality**

## Adding a Third-Party dApp

See `lib/dapps/README.md` for detailed integration guide.

**Quick steps:**
1. Create `dapps/your_dapp/` directory
2. Add `dapp_manifest.yaml`
3. Follow data/domain/presentation structure
4. Import only from `core/*`
5. Test in isolation

## Testing Structure

```
test/
├── unit/
│   ├── features/
│   │   ├── wallet/
│   │   └── node/
│   └── core/
├── widget/
│   └── features/
└── integration/
```

## Code Generation

**Localization:**
```bash
flutter gen-l10n
```

**Rust FFI:**
```bash
flutter_rust_bridge_codegen generate
```

## Build & Run

```bash
# Development
flutter run

# Specific device
flutter run -d android
flutter run -d ios

# Analyze
flutter analyze

# Test
flutter test
```

## Migration Notes

This architecture was established on 2025-10-03 during a refactoring from:
- Flat structure → Feature-oriented structure
- To support third-party dApp integration
- Preparation for future Riverpod migration

**Changes made:**
- ✅ Moved all code to feature modules
- ✅ Created core/ for shared infrastructure
- ✅ Set up dapps/ directory for third-party integrations
- ✅ Updated all imports to absolute paths
- ✅ Zero breaking changes to functionality

## Next Steps

1. **Domain layer**: Add entities and usecases to each feature
2. **Riverpod migration**: Add state management (in progress)
3. **Router abstraction**: Create centralized routing (done)
4. **dApp loader**: Build dynamic dApp discovery and loading
5. **Testing**: Add comprehensive test coverage

---

**Last Updated**: 2025-11-06
**Architecture Version**: 1.1.0
**Maintainer**: Usernode Dev Team
