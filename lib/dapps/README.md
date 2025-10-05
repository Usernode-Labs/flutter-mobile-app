# Third-Party dApps Integration Guide

This directory contains third-party decentralized applications (dApps) that integrate with the Usernode platform.

## Directory Structure

Each dApp should follow this standardized structure:

```
dapps/
└── your_dapp_name/
    ├── dapp_manifest.yaml          # dApp metadata and configuration
    ├── data/                        # Data layer
    │   ├── models/                  # Data models
    │   ├── repositories/            # Data repositories
    │   └── datasources/             # External data sources
    ├── domain/                      # Business logic layer
    │   ├── entities/                # Business entities
    │   └── usecases/                # Use cases
    └── presentation/                # UI layer
        ├── screens/                 # dApp screens
        └── widgets/                 # dApp-specific widgets
```

## dApp Manifest

Create a `dapp_manifest.yaml` file at the root of your dApp directory:

```yaml
name: "Your dApp Name"
id: "your_dapp_id"  # Unique identifier (lowercase, no spaces)
version: "1.0.0"
description: "Brief description of your dApp"
author: "Your Name/Organization"
homepage: "https://your-dapp-website.com"

# Permissions your dApp requires
permissions:
  - wallet_read      # Read wallet addresses
  - wallet_write     # Sign transactions
  - storage_read     # Read from local storage
  - storage_write    # Write to local storage
  - blockchain_rpc   # Access blockchain RPC

# Entry point
entry_point: "lib/dapps/your_dapp_id/presentation/screens/main_screen.dart"

# Navigation
routes:
  - path: "/dapp/your_dapp_id"
    screen: "MainScreen"
  - path: "/dapp/your_dapp_id/feature"
    screen: "FeatureScreen"

# Display in app store
display:
  icon: "assets/dapps/your_dapp_id/icon.png"
  category: "defi"  # defi, nft, gaming, dao, social
  featured: false
```

## Development Guidelines

### 1. Self-Contained

Your dApp should be self-contained within its directory. All code, assets, and dependencies specific to your dApp should reside here.

### 2. Core Dependencies

Access core platform features through the `core/` directory:

```dart
// Access blockchain
import 'package:crypto_mobile_app/core/blockchain/blockchain_service.dart';

// Access storage
import 'package:crypto_mobile_app/core/storage/secure_storage.dart';

// Access theme
import 'package:crypto_mobile_app/core/theme/theme.dart';

// Access shared widgets
import 'package:crypto_mobile_app/core/widgets/common_button.dart';
```

### 3. Isolation

- Do NOT import from other dApps (`lib/dapps/other_dapp/...`)
- Do NOT import from features (`lib/features/wallet/...`)
- Only import from `core/` and your own dApp directory

### 4. State Management

Use the platform's state management solution (currently none, but will use Riverpod in the future).

### 5. Naming Conventions

- Use `snake_case` for file names
- Use `PascalCase` for class names
- Prefix your dApp's classes to avoid conflicts: `YourDappFeatureScreen`

## Testing Your dApp

Create tests in a `test/` directory within your dApp:

```
your_dapp_name/
├── test/
│   ├── data/
│   ├── domain/
│   └── presentation/
└── ...
```

## Example dApp

See `_example_dapp/` for a complete reference implementation.

## Integration Process

1. **Development**: Build your dApp following this structure
2. **Testing**: Test locally within the Usernode app
3. **Review**: Submit for platform review
4. **Approval**: Once approved, your dApp will be available in the Usernode app store

## Support

For questions or support, contact the Usernode developer team:
- Email: dev@usernode.com
- Discord: https://discord.gg/usernode
- Documentation: https://docs.usernode.com/dapp-development

## License

Third-party dApps must comply with the Usernode dApp Terms of Service.
