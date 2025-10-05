# Usernode App Architecture

## Overview

This project follows a **feature-oriented clean architecture** designed to support both first-party features and third-party dApps in a scalable, maintainable structure.

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

### Data Layer
- **Models**: Data transfer objects, API responses
- **Repositories**: Data access logic
- **Datasources**: External data sources (APIs, databases, secure storage)

### Domain Layer
- **Entities**: Pure business objects
- **Usecases**: Business logic operations

### Presentation Layer
- **Screens**: Full-page UI components
- **Widgets**: Reusable UI components

## Dependency Rules

### ✅ Allowed Dependencies

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

## Feature Structure Template

```
features/your_feature/
├── data/
│   ├── models/
│   │   └── your_model.dart
│   ├── repositories/
│   │   └── your_repository.dart
│   └── datasources/
│       └── your_datasource.dart
├── domain/
│   ├── entities/
│   │   └── your_entity.dart
│   └── usecases/
│       └── your_usecase.dart
└── presentation/
    ├── screens/
    │   └── your_screen.dart
    └── widgets/
        └── your_widget.dart
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

**Current**: Direct service calls (Singleton pattern)

**Future**: Riverpod (when migrated)
- Each feature will have its own providers
- Global state in `core/providers/`

## Adding a New Feature

1. Create feature directory under `features/your_feature/`
2. Follow the layer structure (data/domain/presentation)
3. Add screens to `presentation/screens/`
4. Register in navigation if needed
5. Use only `core/*` for shared functionality

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
2. **Riverpod migration**: Add state management
3. **Router abstraction**: Create centralized routing
4. **dApp loader**: Build dynamic dApp discovery and loading
5. **Testing**: Add comprehensive test coverage

---

**Last Updated**: 2025-10-03
**Architecture Version**: 1.0.0
**Maintainer**: Usernode Dev Team
