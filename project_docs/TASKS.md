# Project Tasks

## 🔴 High Priority

- [ ] Wire up real data for dApps (Staking, Swap, Bridge, Liquidity Pool)
- [ ] Implement theme persistence (save user's theme preference)
- [ ] Add Riverpod state management
- [ ] Implement domain layer (entities & usecases) for wallet feature
- [ ] Create router abstraction in `app/router.dart`
- [ ] Fix hardcoded Sentry DSN (move to env variable)

## 🟡 Medium Priority

- [ ] Build dApp loader system for third-party integrations
- [ ] Add language/currency settings persistence
- [ ] Wire up real identity verification status in Profile
- [ ] Wire up real rewards/tier data in Profile
- [ ] Add comprehensive test coverage (target 80%)
- [ ] Create wallet domain entities
- [ ] Create node domain entities
- [ ] Implement error boundary for Rust FFI calls

## 🟢 Low Priority

- [ ] Add animations to navigation transitions
- [ ] Implement pull-to-refresh for all tabs
- [ ] Add empty states for dApps third-party section
- [ ] Investigate Gallery-Mobile*.png assets (1.6 MB - design refs?)
- [ ] Optimize image assets (WebP format)
- [ ] Add analytics for feature usage

## 📦 Backlog

- [ ] Implement biometric authentication toggle in Profile
- [ ] Add transaction history pagination
- [ ] Add search functionality for dApps
- [ ] Implement dApp categories filtering logic
- [ ] Add unit tests for repositories
- [ ] Add widget tests for screens
- [ ] Export account functionality
- [ ] Account deletion flow

## 🎯 Current Sprint (Week of 2025-10-03)

### ✅ Completed
- [x] Architecture refactoring to feature-oriented structure
- [x] Dead code removal (~90 lines)
- [x] Navigation redesign - 5 tabs (Home, Wallet, dApps, Profile, Node)
- [x] Account switcher widget implementation
- [x] Home screen dashboard with quick actions
- [x] dApps marketplace screen with category filters
- [x] Profile screen with account management
- [x] Wallet screen simplification

### In Progress
- None

### Blocked
- None

### Notes
- Navigation redesign complete (7 phases)
- All new features compile with 0 errors
- Ready for backend data integration
