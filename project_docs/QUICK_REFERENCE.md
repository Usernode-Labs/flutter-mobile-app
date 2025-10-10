# Quick Reference Guide

**Last Updated**: 2025-10-03

## 🗂️ Project Structure

```
lib/
├── app/                    # App configuration
│   └── main_app.dart      # 5-tab navigation root
├── core/                  # Shared infrastructure
│   ├── widgets/           # Reusable widgets
│   │   ├── account_switcher.dart        # Account selector
│   │   ├── quick_action_button.dart     # Dashboard buttons
│   │   └── ...
│   ├── theme/            # Material 3 theme
│   ├── constants/        # App constants
│   └── feature_flags.dart # Feature toggles
├── features/             # Feature modules
│   ├── home/
│   │   └── presentation/screens/home_screen.dart
│   ├── wallet/
│   │   └── presentation/screens/wallet_screen.dart
│   ├── dapps/
│   │   ├── presentation/
│   │   │   ├── screens/dapps_screen.dart
│   │   │   └── widgets/dapp_card.dart
│   ├── profile/
│   │   └── presentation/screens/profile_screen.dart
│   └── node/
│       └── presentation/screens/node_status_screen.dart
└── dapps/               # Third-party dApps
```

---

## 📱 Navigation Structure

### Bottom Navigation Bar (5 Tabs)

```
┌────────────────────────────────────────┐
│ [Home] [Wallet] [dApps] [Profile] [Node]│
└────────────────────────────────────────┘
```

| Tab | Purpose | Key Features |
|-----|---------|-------------|
| **Home** | Dashboard | Quick actions, rewards, activity |
| **Wallet** | Crypto ops | Balances, transactions, send/receive |
| **dApps** | Marketplace | First/third-party dApps, categories |
| **Profile** | Settings | Accounts, identity, rewards, prefs |
| **Node** | Node mgmt | Status, peers, configuration |

---

## 🔧 Feature Flags

**Location**: `assets/feature_flags.json`

```json
{
  "enabled": ["home", "wallet", "dapps", "profile", "node"],
  "order": ["home", "wallet", "dapps", "profile", "node"]
}
```

**Note**: Changes require app restart (not hot reload)

---

## 🎨 Reusable Widgets

### AccountSwitcher
**Path**: `lib/core/widgets/account_switcher.dart`
**Usage**: App bar account selector
```dart
// In AppBar actions:
actions: const [
  Padding(
    padding: EdgeInsets.only(right: 8),
    child: AccountSwitcher(),
  ),
],
```

### QuickActionButton
**Path**: `lib/core/widgets/quick_action_button.dart`
**Usage**: Home screen quick actions
```dart
QuickActionButton(
  icon: Icons.arrow_upward,
  label: 'Send',
  color: colorScheme.primary,
  onTap: () { /* navigate */ },
)
```

### DAppCard
**Path**: `lib/features/dapps/presentation/widgets/dapp_card.dart`
**Usage**: dApps marketplace listings
```dart
DAppCard(
  name: 'Staking',
  description: 'Lock tokens to earn rewards',
  icon: Icons.lock,
  color: colorScheme.tertiary,
  badge: 'New',
  onTap: () { /* launch dApp */ },
)
```

---

## 🏠 Home Screen

### Quick Actions Grid (3×2)
```
┌─────────────────────────────────────┐
│  [Send]     [Receive]     [Swap]   │
│  [Bridge]   [Stake]       [Rewards] │
└─────────────────────────────────────┘
```

**Functional**:
- Send → `SendScreen`
- Receive → `ReceiveScreen`
- Rewards → `RewardsBreakdownScreen`

**Placeholders** (show snackbar):
- Swap, Bridge, Stake

---

## 💳 Wallet Screen

### Features
- Account info header
- Refresh button
- Send/Receive/Bridge quick actions
- Token balances list
- Recent activity

### Removed
- Account management button (→ Profile screen)
- Settings button (→ Profile screen)

---

## 📦 dApps Screen

### Layout
```
┌─────────────────────────────────────┐
│ [All] [DeFi] [NFT] [Gaming] [DAO]  │  ← Category filters
├─────────────────────────────────────┤
│ First-Party dApps                   │
│  • Staking (New)                    │
│  • Swap                             │
│  • Bridge                           │
│  • Liquidity Pool                   │
├─────────────────────────────────────┤
│ Third-Party dApps                   │
│  (placeholder)                      │
└─────────────────────────────────────┘
```

### First-Party dApps
1. **Staking** - Lock tokens, earn rewards (has "New" badge)
2. **Swap** - Exchange tokens
3. **Bridge** - Cross-chain transfers
4. **Liquidity Pool** - Provide liquidity, earn fees

---

## 👤 Profile Screen

### Sections

**User Info**
- Colored avatar (based on address)
- Account name
- Address (tap to copy)

**Identity & Verification**
- Status card (placeholder)

**Rewards & Tier**
- Tier level (placeholder: "Basic")
- Points (placeholder: "1,234")
- Multiplier (placeholder: "2.5x")

**Account Management**
- Create New Account → `AccountOnboardingScreen`
- Import from Seed → `ImportSeedScreen`
- Import from Private Key → `ImportPrivateKeyScreen`

**Preferences**
- Theme (System/Light/Dark)
- Language (English/Français/Español)
- Currency (USD/EUR/GBP)

---

## 🔍 Common Tasks

### Add a New Quick Action
1. Edit `lib/features/home/presentation/screens/home_screen.dart`
2. Add `QuickActionButton` widget in grid
3. Wire up `onTap` navigation

### Add a First-Party dApp
1. Edit `lib/features/dapps/presentation/screens/dapps_screen.dart`
2. Add `DAppCard` in "First-Party dApps" section
3. Implement `onTap` handler

### Enable/Disable a Tab
1. Edit `assets/feature_flags.json`
2. Add/remove feature from "enabled" array
3. Restart app (not hot reload)

### Add a Preference Option
1. Edit `lib/features/profile/presentation/screens/profile_screen.dart`
2. Add `_ListTileButton` in Preferences section
3. Implement dialog in `onTap`

---

## 🐛 Troubleshooting

### Issue: Tabs not showing after feature_flags.json change
**Solution**: Restart app (feature flags load at startup)

### Issue: Account switcher not updating
**Solution**: Check `mounted` before setState, ensure backend restart completes

### Issue: Navigation assertion error
**Solution**: Use `if (mounted)` and `if (context.mounted)` for async navigation

### Issue: Imports not resolving

---

## 🚀 Setup & Run (Quick)

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
**Solution**: Use absolute imports: `package:crypto_mobile_app/...`

---

## 📊 Key Files

### Most Frequently Modified
1. `lib/features/home/presentation/screens/home_screen.dart` - Quick actions
2. `lib/features/dapps/presentation/screens/dapps_screen.dart` - dApp listings
3. `lib/features/profile/presentation/screens/profile_screen.dart` - Profile sections
4. `assets/feature_flags.json` - Enable/disable features

### Configuration
- `lib/core/feature_flags.dart` - Feature flag logic
- `assets/feature_flags.json` - Feature flag values
- `lib/l10n/app_en.arb` - Localization strings

### Reusable Components
- `lib/core/widgets/account_switcher.dart`
- `lib/core/widgets/quick_action_button.dart`
- `lib/features/dapps/presentation/widgets/dapp_card.dart`

---

## 🎯 Development Workflow

### Adding a New Feature
1. Check if feature flag needed
2. Create in appropriate `features/*/` directory
3. Follow clean architecture (data/domain/presentation)
4. Add to navigation if needed
5. Update feature flags if needed
6. Test with `flutter analyze`
7. Document in CHANGELOG.md

### Making UI Changes
1. Read existing file first
2. Use Material 3 theme colors
3. Follow 8px spacing grid
4. Add proper error handling
5. Include loading states
6. Test on device

### Testing Changes
1. `flutter analyze` - Check for errors
2. Hot restart (for feature flags)
3. Test all affected navigation flows
4. Verify on different screen sizes
5. Check dark mode compatibility

---

## 📞 Getting Help

### Documentation
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System design
- [NAVIGATION_REDESIGN_2025-10-03.md](./NAVIGATION_REDESIGN_2025-10-03.md) - Redesign details
- [CHANGELOG.md](./CHANGELOG.md) - Change history
- [TASKS.md](./TASKS.md) - Active tasks

### Common Questions

**Q: How do I add a new tab?**
A: Add to AppFeature enum, update feature_flags, create screen, add to main_app.dart

**Q: Where do I put shared widgets?**
A: `lib/core/widgets/` for app-wide, `features/*/presentation/widgets/` for feature-specific

**Q: How do I access current account?**
A: `await AccountsRepository.create()` → `getActive()`

**Q: Where are localization strings?**
A: `lib/l10n/app_en.arb`, access via `AppLocalizations.of(context)`

---

**Created**: 2025-10-03
**Maintained By**: Development Team
