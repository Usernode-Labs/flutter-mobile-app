# Project Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### 🎯 Planned
- Wire up real backend data for dApps (Staking, Swap, Bridge, Liquidity Pool)
- Add Riverpod state management
- Implement domain layer for all features
- Create router abstraction
- Build dApp loader system
- Implement theme persistence
- Add language/currency settings persistence

---

## [2025-10-03] - Navigation Redesign & Feature Expansion

### ✨ Added
**Navigation & Structure:**
- 5-tab bottom navigation (Home, Wallet, dApps, Profile, Node)
- Account switcher widget in app bar with bottom sheet selector
- Feature flags support for dApps and Profile tabs
- Localization strings for new tabs (l10n.dapps, l10n.profile)

**Home Screen Dashboard:**
- Quick actions grid with 6 buttons (Send, Receive, Swap, Bridge, Stake, Rewards)
- `QuickActionButton` reusable widget
- Dashboard-style layout focused on common actions
- Navigation to Send, Receive, and Rewards screens

**dApps Marketplace:**
- dApps screen with category filters (All, DeFi, NFT, Gaming, DAO)
- `DAppCard` reusable widget for dApp listings
- 4 first-party dApps: Staking (with "New" badge), Swap, Bridge, Liquidity Pool
- Horizontal scrolling category filter chips
- Placeholder for third-party dApps with developer guidance

**Profile Screen:**
- Real account data integration via `AccountsRepository`
- Colored avatar based on account address hash
- Tap-to-copy address functionality
- Identity & Verification status card (placeholder)
- Rewards & Tier card (placeholder: tier, points, multiplier)
- Account Management: Create new account, Import from seed, Import from private key
- Preferences: Theme selector, Language selector, Currency selector
- All preferences show dialogs with placeholder options

**Account Switcher:**
- `lib/core/widgets/account_switcher.dart` - reusable component
- Compact pill-shaped button showing avatar + shortened address
- Bottom sheet with account list, colored avatars, selection state
- Smooth account switching with backend restart
- Snackbar confirmation on switch

**Widgets:**
- `lib/core/widgets/quick_action_button.dart` - dashboard quick actions
- `lib/features/dapps/presentation/widgets/dapp_card.dart` - dApp cards
- `lib/core/widgets/account_switcher.dart` - account switching

### 🔄 Changed
**Wallet Screen:**
- Removed account management button (moved to Profile screen)
- Simplified header - now shows account info + refresh only
- Account management bottom sheet preserved but unused (`_openAccountManager`)
- Focused on crypto operations: balances, transactions, send/receive
- Account switching now via AccountSwitcher in app bar

**Home Screen:**
- Removed horizontal card scroll for promo cards
- Added Quick Actions grid as primary UI element
- Maintained rewards and activity sections

**Feature Flags:**
- Updated `assets/feature_flags.json` to enable 5 tabs
- Order: home → wallet → dapps → profile → node

### 🗑️ Removed
- Account management settings button from Wallet screen header
- Horizontal promo cards from Home screen (replaced with quick actions)

### 🐛 Fixed
- Account switcher async navigation issue (Navigator assertion error)
- Proper mounted checks in async operations
- Context usage across async gaps properly guarded

### 📊 Impact
**New Features:**
- **5 navigation tabs** (up from 3)
- **3 major screens** created/redesigned (dApps, Profile, Home)
- **3 reusable widgets** created
- **10+ functional flows** implemented

**Code Quality:**
- **Build Status**: ✅ Passing
- **Errors**: 0
- **New Warnings**: 0
- **Total Warnings**: 21 (all pre-existing)
- **Files Created**: 6 (screens + widgets)
- **Files Modified**: 8

**User Experience:**
- Quick access to 6 common actions from Home
- Dedicated dApps marketplace for discoverability
- Centralized account & settings management in Profile
- One-tap account switching from any screen
- Clean separation of concerns across tabs

---

## [2025-10-03] - Architecture Refactoring

### ✨ Added
- New feature-oriented directory structure
- `core/` directory for shared infrastructure
- `features/` directory with clean architecture layers
- `dapps/` directory for third-party integrations
- `app/` directory for app-level configuration
- `docs/ARCHITECTURE.md` documentation
- `dapps/README.md` integration guide for third-party developers
- Empty domain layer directories prepared for future use

### 🔄 Changed
- **BREAKING (Internal)**: Moved all screens to `features/*/presentation/screens/`
- **BREAKING (Internal)**: Moved all models to `features/*/data/models/`
- **BREAKING (Internal)**: Moved all services to `features/*/data/repositories/`
- Updated 200+ import statements to absolute paths
- Moved `theme/` → `core/theme/`
- Moved `constants/` → `core/constants/`
- Moved `utils/` → `core/utils/`
- Moved `widgets/common/` → `core/widgets/`
- Moved `config/feature_flags.dart` → `core/feature_flags.dart`

### 🗑️ Removed
- `lib/constants/nfc_constants.dart` (unused)
- `lib/gen_l10n/localization_extensions.dart` (unused NFC localization)
- Unused constants from `app_constants.dart` (~50 lines)
- Commented-out dead code in wallet screens (~10 lines)

### 🐛 Fixed
- All import paths now use absolute imports
- Zero compilation errors after refactoring

### 📊 Impact
- **Files Moved**: ~50 files
- **Imports Updated**: 200+
- **Code Removed**: ~90 lines
- **Build Status**: ✅ Passing
- **Errors**: 0
- **Warnings**: 15 (pre-existing)

---

## [2025-10-02] - Identity Flow Rework

### ✨ Added
- Reworked Identity flow/UX (commit: 7c60c79)
- Added NFC scanner - WIP (commit: c8ec9b7)

### 🐛 Fixed
- Missing named parameter (commit: bf652ef)
- Multiple backend init bugfix (commits: 027b558, 30420c7)

---

## Template for Future Entries

## [YYYY-MM-DD] - Title

### ✨ Added
- New feature or capability

### 🔄 Changed
- Changes to existing functionality

### 🗑️ Removed
- Removed features or files

### 🐛 Fixed
- Bug fixes

### 🔒 Security
- Security improvements or fixes

### 📊 Impact
- Measurable impact of changes
