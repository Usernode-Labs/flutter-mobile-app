# UI Components Audit & Migration Roadmap

> Archived from Intent workspace note `b7d536c4-7c05-4228-830a-d9b0c06a5dcd` (Feb 2026).
> Full unabridged research content.

---

Comprehensive audit of all UI screens and widgets, design system coverage analysis, and prioritized migration roadmap.

---

## A. Design System Widget Catalog

18 widgets in `lib/design_system/src/`. All use ThemeExtension tokens, are presentation-only, and follow M3 alignment.

| # | Widget | File | Purpose | Tokens Used | Widgetbook | Quality |
|---|--------|------|---------|-------------|------------|---------|
| 1 | BottomNav | `src/bottom_nav.dart` | M3 NavigationBar wrapper with badges, indicator shapes, enabled/disabled states | colorScheme | Yes | Excellent — M3-backed, accessible |
| 2 | Button | `src/button.dart` | 4 variants (primary/tonal/outlined/surface) × 3 sizes, M3 FilledButton/OutlinedButton | AppRadii, AppSizing, AppSpacing, colorScheme | Yes (2 use cases) | Excellent — full M3 integration |
| 3 | ChallengeActivitySummary | `src/challenge_activity_summary.dart` | Empty-state illustration + "Done/Missed" pills | AppSpacing, AppRadii, AppSizing, AppSemanticColors | Yes | Good — SVG caching, semantic colors |
| 4 | ChallengeCard | `src/challenge_card.dart` | 4-variant card (active/ongoing/completed/missed) with animated sweep border | AppSpacing, AppRadii, AppElevation, AppSizing, AppSemanticColors | Yes | Excellent — animated, category-colored |
| 5 | ChallengeCategoryIcon | `src/challenge_category_icon.dart` | SVG geometric icon per category with muted mode | AppSemanticColors, colorScheme | Partial (via card) | Good — cached SVGs, muted state |
| 6 | ChallengeCategoryTile | `src/challenge_category_tile.dart` | Expandable tile grouping sub-challenges by category | AppSpacing, AppRadii, AppOpacity | Yes (2 use cases) | Good — animated expand/collapse |
| 7 | ChallengeDetailPage | `src/challenge_detail_page.dart` | Full-page detail with TopAppBar, sections, reward card | AppSpacing, AppRadii | Yes | Good — composes TopAppBar + ChallengeRewardCard |
| 8 | ChallengeRewardCard | `src/challenge_reward_card.dart` | Category-colored reward card with sealed data variants | AppSpacing, AppRadii, AppSemanticColors | Partial (via detail page) | Excellent — sealed class pattern |
| 9 | DropdownChain | `src/dropdown_chain.dart` | Horizontal row of filter DropdownChips with chevrons | AppSpacing | Yes | Good — composes DropdownChip |
| 10 | DropdownChip | `src/dropdown_chip.dart` | Filter chip with dropdown arrow, selected/unselected states | AppSpacing, AppRadii, AppOpacity | Yes | Good — presentation-only |
| 11 | DropdownSheet | `src/dropdown_sheet.dart` | Modal bottom sheet with selectable options list | AppSpacing | Yes | Good — M3 showModalBottomSheet |
| 12 | EpochPerformancePage | `src/epoch_performance_page.dart` | Epoch progress, metrics, epoch picker | AppSpacing | Yes | Good — composes AppProgressBar (core) |
| 13 | LeaderboardStatsCard | `src/leaderboard_stats_card.dart` | Stats summary with dot-matrix chart, bucket selection | AppSpacing, AppRadii, AppOpacity | Yes (3 use cases) | Excellent — animated, interactive |
| 14 | NavIndicatorShapes | `src/nav_indicator_shapes.dart` | Circle/hexagon/blob ShapeBorder for BottomNav indicator | None (geometry helper) | N/A (helper) | Good — pure geometry |
| 15 | RankBadge | `src/rank_badge.dart` | 40px circle showing rank number for leaderboard rows | AppSizing, colorScheme | Yes (2 use cases) | Good — simple, tokens-only |
| 16 | ScoreHeader | `src/score_header.dart` | Circular score display with arc, glow, countdown, CTA | AppSpacing, AppOpacity, AppSemanticColors | Yes | Excellent — complex glow painter |
| 17 | Tabs | `src/tabs.dart` | M3 TabBar + TabBarView with inline badges | AppSpacing, colorScheme | Yes | Good — M3 TabBar, badge support |
| 18 | TopAppBar | `src/top_app_bar.dart` | Sliver app bar, small/large variants with collapsing | AppSpacing, AppRadii, AppSizing | Yes | Excellent — smooth collapse animation |

**Widgetbook Summary**: 15/18 have dedicated use cases, 2 partial (embedded in composites), 1 is a helper (N/A).

---

## B. Core Widget Assessment

12 widgets in `lib/core/widgets/`. Mixed token usage and state management patterns.

| # | Widget | File | Token System | Presentation-Only? | Migration Recommendation |
|---|--------|------|-------------|---------------------|--------------------------|
| 1 | AppActionButton | `core/widgets/app_action_button.dart` | Legacy `design_tokens.dart` constants (kIconSizeSmall, kSpace8, kBorderRadiusLarge) | Yes | **Deprecate** — specialized, low reuse |
| 2 | AppAppBar | `core/widgets/app_bar.dart` | Mixed: hardcoded fontSize:18, Colors.black alpha, some theme | **No** — ConsumerWidget, imports NodeStatusIcon provider | **Keep as-is** — refactor to inject status as param |
| 3 | AppBottomSheet | `core/widgets/app_bottom_sheet.dart` | Legacy `design_tokens.dart` (kSpace16, kBorderRadiusFull, kAlphaSecondary) | Yes | **Migrate to DS** — core presentation primitive |
| 4 | AppButton | `core/widgets/app_button.dart` | Legacy `design_tokens.dart` (kButtonHeightSmall, kRadiusFull, kSpace8) | Yes | **Migrate to DS** — superseded by DS Button |
| 5 | AppCard | `core/widgets/app_card.dart` | Legacy `design_tokens.dart` (kSpace12, kBorderRadiusLarge, kElevationNone) | Yes | **Migrate to DS** — no DS equivalent yet |
| 6 | AppDrawer | `core/widgets/app_drawer.dart` | Hardcoded padding, no design tokens | **No** — ConsumerStatefulWidget, heavy business logic | **Deprecate** — extract presentation from logic |
| 7 | AppProgressBar | `core/widgets/app_progress_bar.dart` | Hardcoded (height 12, radius 2), some theme colors | Yes | **Migrate to DS** — used by EpochPerformancePage |
| 8 | AppTextField | `core/widgets/app_text_field.dart` | Legacy `design_tokens.dart` (kBorderRadiusMedium, kSpace16, kAlphaDisabled) | Yes | **Migrate to DS** — no DS equivalent yet |
| 9 | FpsMonitor | `core/widgets/fps_monitor.dart` | Hardcoded (Colors.black87, Colors.greenAccent, fontSize:10) | Yes (debug only) | **Keep as-is** — debug overlay, tree-shaken in release |
| 10 | NodeStatusIcon | `core/widgets/node_status_icon.dart` | Hardcoded constraints, theme colors | **No** — ConsumerWidget, watches nodeStatusProvider | **Keep as-is** — domain-specific, refactor later |
| 11 | ProducedBlockCard | `core/widgets/produced_block_card.dart` | Hardcoded (padding 16/12, radius 20, fontSize:9), theme colors | Yes but FRB types in constructor | **Keep as-is** — domain-specific, FRB-coupled |
| 12 | WonSlotItem | `core/widgets/won_slot_item.dart` | Hardcoded (Colors.green/red/orange, fontSize:11, radius 8/12) | Yes but FRB types in constructor | **Keep as-is** — domain-specific, FRB-coupled |

**Summary**: 4 widgets should migrate to DS, 2 should be deprecated, 6 kept as-is (3 domain-specific, 2 provider-coupled, 1 debug tool).

---

## C. Screen-by-Screen Coverage Matrix

31 screens across 8 feature domains. "DS Widgets" = design system widgets used. "Complexity" = migration complexity.

### Challenges (4 screens)

| Screen | File | Styling | DS Widgets Used | Complexity | Priority |
|--------|------|---------|----------------|------------|----------|
| ChallengesScreen | `challenges/screens/challenges_screen.dart` | DS tokens (AppSemanticColors, AppSpacing, AppRadii) | ScoreHeader, ChallengeCard, DropdownChain, Tabs, BottomNav, ChallengeActivitySummary, ChallengeCategoryTile | Low | P1 — already migrated |
| ChallengeDetailScreen | `challenges/screens/challenge_detail_screen.dart` | DS tokens (AppSemanticColors, AppSpacing) | ChallengeDetailPage, ChallengeRewardCard | Low | P1 — already migrated |
| EpochPerformanceScreen | `challenges/screens/epoch_performance_screen.dart` | DS tokens | EpochPerformancePage | Low | P1 — already migrated |
| ChallengesDelegates | `challenges/screens/challenges_delegates.dart` | DS tokens (AppSpacing) | Helper delegates for sliver list | Low | P1 — already migrated |

### Home (1 screen)

| Screen | File | Styling | DS Widgets Used | Complexity | Priority |
|--------|------|---------|----------------|------------|----------|
| HomeScreen | `home/screens/home_screen.dart` | DS tokens (AppSemanticColors, AppSpacing, AppRadii, AppElevation) | BottomNav (M3 NavigationBar) | Low | P1 — already migrated |

### Leaderboard (1 screen)

| Screen | File | Styling | DS Widgets Used | Complexity | Priority |
|--------|------|---------|----------------|------------|----------|
| LeaderboardScreen | `leaderboard/screens/leaderboard_screen.dart` | DS tokens | LeaderboardStatsCard, RankBadge, DropdownChain, Tabs, ChallengeCategoryTile | Low | P1 — already migrated |

### Wallet (4 screens)

| Screen | File | Styling | DS Widgets Used | Complexity | Priority |
|--------|------|---------|----------------|------------|----------|
| WalletScreen | `wallet/screens/wallet_screen.dart` | DS tokens (AppSemanticColors, AppSpacing, AppRadii, AppElevation) + some hardcoded radius/padding | None | Low | P2 — user-facing, mostly token-aligned |
| SendScreen | `wallet/screens/send_screen.dart` | Mixed: theme + hardcoded colors, padding, fontSize | None | Medium | P2 — needs form widget + color token migration |
| TransactionSuccessScreen | `wallet/screens/transaction_success_screen.dart` | Mixed: hardcoded Colors.green/white, fontSize:18, alpha values | None | Medium | P2 — needs result page widget |
| TransactionFailedScreen | `wallet/screens/transaction_failed_screen.dart` | Mixed: hardcoded Colors.red/white, fontSize:18, alpha values | None | Medium | P2 — needs result page widget |

### Settings (1 screen)

| Screen | File | Styling | DS Widgets Used | Complexity | Priority |
|--------|------|---------|----------------|------------|----------|
| BackgroundProductionSettings | `settings/screens/background_production_settings_screen.dart` | DS tokens (AppSemanticColors, AppSpacing, AppRadii) + some hardcoded fontSize:12 | None | Low | P2 — mostly token-aligned, minor cleanup |

### Node (11 screens)

| Screen | File | Styling | DS Widgets Used | Complexity | Priority |
|--------|------|---------|----------------|------------|----------|
| NodeStatusScreen | `node/screens/node_status_screen.dart` | DS tokens + hardcoded EdgeInsets/BorderRadius/fontSize:10 | None | Medium | P3 — deeply coupled to FRB/Riverpod |
| BlockDetailsScreen | `node/screens/block_details_screen.dart` | Mixed: theme + some hardcoded values | None | Medium | P3 — domain-specific |
| MempoolDetailsScreen | `node/screens/mempool_details_screen.dart` | Theme + Colors.orange, fontSize:11 | None | Medium | P3 — needs semantic color for warnings |
| NodePeersScreen | `node/screens/node_peers_screen.dart` | Theme tokens | None | Low | P3 — simple list screen |
| NodeStatusProducedBlocksScreen | `node/screens/node_status_produced_blocks_screen.dart` | DS tokens | None | Low | P3 — simple list |
| NodeWonSlotsScreen | `node/screens/node_won_slots_screen.dart` | DS tokens | None | Low | P3 — simple list |
| ProducedBlockDetailsScreen | `node/screens/produced_block_details_screen.dart` | Theme tokens | None | Low | P3 — detail view |
| ProducedBlocksScreen | `node/screens/produced_blocks_screen.dart` | DS tokens | None | Medium | P3 — **DEPRECATED** (replaced by EpochPerformanceScreen) |
| SlotAssignmentsScreen | `node/screens/slot_assignments_screen.dart` | Theme + Colors.grey/black87/white/orange hardcoded | None | Medium | P3 — many hardcoded colors |
| SlotProductionStatsScreen | `node/screens/slot_production_stats_screen.dart` | Theme + Colors.amber/blue/green/red hardcoded | None | Medium | P3 — chart colors need semantic tokens |
| NodeStatusSummaryModal | `node/screens/widgets/node_status_summary_modal.dart` | Theme + hardcoded EdgeInsets/BorderRadius | None | Medium | P3 — modal, hardcoded layout |

### Onboarding (7 screens)

| Screen | File | Styling | DS Widgets Used | Complexity | Priority |
|--------|------|---------|----------------|------------|----------|
| ExactAlarmPermission1Screen | `onboarding/screens/exact_alarm_permission1_screen.dart` | Theme + Colors.green/orange hardcoded | None | Low | P4 — edge case, one-time screen |
| BatteryPermission2Screen | `onboarding/screens/battery_permission2_screen.dart` | DS tokens | None | Low | P4 — edge case |
| NotificationPermission3Screen | `onboarding/screens/notification_permission3_screen.dart` | DS tokens | None | Low | P4 — edge case |
| OnboardingBatteryCompleteScreen | `onboarding/screens/onboarding_battery_complete_screen.dart` | DS tokens | None | Low | P4 — edge case |
| WelcomeClaimScreen | `onboarding/screens/welcome_claim_screen.dart` | Theme + hardcoded EdgeInsets.all(16) | None | Low | P4 — edge case |
| WelcomeSetupScreen | `onboarding/screens/welcome_setup_screen.dart` | DS tokens | None | Low | P4 — edge case |
| ImportApiAccountScreen | `onboarding/screens/import_api_account_screen.dart` | DS tokens | None | Low | P4 — edge case |

### Splash (1 screen)

| Screen | File | Styling | DS Widgets Used | Complexity | Priority |
|--------|------|---------|----------------|------------|----------|
| SplashScreen | `splash/screens/splash_screen.dart` | DS tokens | None | Low | P4 — one-time display |

### DApps (1 screen)

| Screen | File | Styling | DS Widgets Used | Complexity | Priority |
|--------|------|---------|----------------|------------|----------|
| DappsScreen | `dapps/dapps_screen.dart` | Theme + hardcoded EdgeInsets | None | Low | P4 — WebView wrapper |

**Total: 31 screens. Already migrated: 6 (challenges + home + leaderboard). Remaining: 25.**

---

## D. Coverage Gap Analysis

Missing widget types that unmigrated screens need:

### 1. Result Page / Status Page Widget
- **Screens needing it**: TransactionSuccessScreen, TransactionFailedScreen, OnboardingBatteryCompleteScreen
- **Proposed design**: Full-page layout with icon/illustration, headline, body text, and action button(s). Accept `ResultPageVariant` (success/failure/info) to drive icon and semantic coloring.
- **Estimated effort**: Small (1 widget)

### 2. Form Input / Text Field Widget
- **Screens needing it**: SendScreen, ImportApiAccountScreen
- **Proposed design**: DS wrapper around `AppTextField` using ThemeExtension tokens (AppRadii, AppSpacing). Support label, helper text, error state, suffix/prefix icons.
- **Estimated effort**: Small (1 widget, wraps existing AppTextField pattern)

### 3. Status Badge / Indicator
- **Screens needing it**: WonSlotItem, NodeStatusScreen, SlotAssignmentsScreen, MempoolDetailsScreen
- **Proposed design**: Compact colored indicator with icon + label. Accept status enum → maps to semantic colors. Replace hardcoded Colors.green/red/orange.
- **Estimated effort**: Small (1 widget)

### 4. Settings Toggle / Switch Row
- **Screens needing it**: BackgroundProductionSettingsScreen
- **Proposed design**: M3 SwitchListTile wrapper with consistent padding, label, and description. Already mostly uses M3 components; formalize as DS widget.
- **Estimated effort**: Small (1 widget)

### 5. Data Card / Metric Tile
- **Screens needing it**: NodeStatusScreen, SlotProductionStatsScreen, BlockDetailsScreen, MempoolDetailsScreen
- **Proposed design**: Bordered card with icon container, title, subtitle, trailing value. Standardize the repeated pattern from node screens. M3 ListTile-based.
- **Estimated effort**: Small (1 widget)

### 6. Permission Page Layout
- **Screens needing it**: ExactAlarmPermission1Screen, BatteryPermission2Screen, NotificationPermission3Screen
- **Proposed design**: Full-page layout with illustration, title, description, and primary action button. Similar to ResultPage but for permission requests.
- **Estimated effort**: Small (could extend ResultPage widget or share base layout)

---

## E. Anti-Pattern Catalog

### 1. Hardcoded Colors (replace with `colorScheme` or `AppSemanticColors`)

| File | Line | Code | DS Alternative |
|------|------|------|---------------|
| `core/widgets/won_slot_item.dart` | 43 | `Colors.green` | `semantic.success.color` |
| `core/widgets/won_slot_item.dart` | 49 | `Colors.red` | `colorScheme.error` |
| `core/widgets/won_slot_item.dart` | 55 | `Colors.orange` | `semantic.flash.color` (warning) |
| `node/screens/slot_assignments_screen.dart` | 378 | `Colors.grey.shade300` | `colorScheme.outlineVariant` |
| `node/screens/slot_assignments_screen.dart` | 499 | `Colors.orange` | `semantic.flash.color` |
| `node/screens/slot_assignments_screen.dart` | 529 | `Colors.black87` | `colorScheme.onSurface` |
| `node/screens/slot_assignments_screen.dart` | 530 | `Colors.white` | `colorScheme.surfaceContainerLowest` |
| `node/screens/slot_production_stats_screen.dart` | 136 | `Colors.amber` | `semantic.flash.color` |
| `node/screens/slot_production_stats_screen.dart` | 145 | `Colors.blue` | `semantic.technical.color` |
| `node/screens/slot_production_stats_screen.dart` | 159 | `Colors.green` | `semantic.success.color` |
| `node/screens/slot_production_stats_screen.dart` | 168 | `Colors.red` | `colorScheme.error` |
| `node/screens/mempool_details_screen.dart` | 164 | `Colors.orange` | `semantic.flash.color` |
| `wallet/screens/transaction_failed_screen.dart` | 98 | `Colors.white` | `colorScheme.onPrimary` |
| `wallet/screens/transaction_success_screen.dart` | 115 | `Colors.white` | `colorScheme.onPrimary` |
| `wallet/screens/wallet_screen.dart` | 528 | `Colors.orange` | `semantic.flash.color` |
| `onboarding/screens/exact_alarm_permission1_screen.dart` | 114 | `Colors.green`, `Colors.orange` | `semantic.success.color`, `semantic.flash.color` |

### 2. Hardcoded Font Sizes (replace with `textTheme` styles)

| File | Line | Code | DS Alternative |
|------|------|------|---------------|
| `core/widgets/app_bar.dart` | 56 | `fontSize: 18` | `textTheme.titleLarge` |
| `core/widgets/app_drawer.dart` | 265 | `fontSize: 11` | `textTheme.labelSmall` |
| `core/widgets/won_slot_item.dart` | 138 | `fontSize: 11` | `textTheme.labelSmall` |
| `core/widgets/produced_block_card.dart` | 193 | `fontSize: 9` | `textTheme.labelSmall` (scaled) |
| `node/screens/node_status_screen.dart` | 447 | `fontSize: 10` | `textTheme.labelSmall` |
| `node/screens/mempool_details_screen.dart` | 229 | `fontSize: 11` | `textTheme.labelSmall` |
| `wallet/screens/transaction_failed_screen.dart` | 99 | `fontSize: 18` | `textTheme.titleLarge` |
| `wallet/screens/transaction_success_screen.dart` | 116 | `fontSize: 18` | `textTheme.titleLarge` |
| `settings/screens/background_production_settings_screen.dart` | 623 | `fontSize: 12` | `textTheme.bodySmall` |
| `wallet/screens/send_screen.dart` | 262 | `fontSize: 16` | `textTheme.bodyLarge` |

### 3. Legacy Token Imports (replace with ThemeExtension)

| File | Line | Import |
|------|------|--------|
| `core/widgets/app_action_button.dart` | 2 | `design_tokens.dart` |
| `core/widgets/app_button.dart` | 2 | `design_tokens.dart` |
| `core/widgets/app_card.dart` | 2 | `design_tokens.dart` |
| `core/widgets/app_bottom_sheet.dart` | 2 | `design_tokens.dart` |
| `core/widgets/app_text_field.dart` | 3 | `design_tokens.dart` |

### 4. Hardcoded Layout Values (replace with AppSpacing / AppRadii tokens)

| File | Line | Code | DS Alternative |
|------|------|------|---------------|
| `core/widgets/app_progress_bar.dart` | 39 | `BorderRadius.circular(2)` | `radii.borderRadiusSmall` |
| `core/widgets/produced_block_card.dart` | 57 | `BorderRadius.circular(20)` | `radii.borderRadiusLargeIncreased` |
| `node/screens/node_status_screen.dart` | 526 | `EdgeInsets.all(20)` | `spacing.space24` (nearest token) |
| `node/screens/node_status_screen.dart` | 739 | `BorderRadius.circular(12)` | `radii.borderRadiusMedium` |
| `node/screens/widgets/node_status_summary_modal.dart` | 161 | `BorderRadius.circular(4)` | `radii.borderRadiusSmall` |
| `node/screens/widgets/node_status_summary_modal.dart` | 666 | `BorderRadius.circular(12)` | `radii.borderRadiusMedium` |
| `wallet/screens/wallet_screen.dart` | 280 | `BorderRadius.circular(20)` | `radii.borderRadiusLargeIncreased` |
| `wallet/screens/wallet_screen.dart` | 365 | `BorderRadius.circular(8)` | `radii.borderRadiusSmall` |

### 5. Provider Coupling in Widgets (should be in screen layer only)

| File | Widget | Issue |
|------|--------|-------|
| `core/widgets/app_bar.dart` | AppAppBar | ConsumerWidget — watches NodeStatusIcon which has provider deps |
| `core/widgets/app_drawer.dart` | AppDrawer | ConsumerStatefulWidget — watches buildEnvProvider, nodeStatusProvider |
| `core/widgets/node_status_icon.dart` | NodeStatusIcon | ConsumerWidget — watches nodeStatusProvider |

---

## F. Migration Roadmap

### Wave 1: Quick Wins (6 screens)
**Theme**: Token cleanup on already-aligned screens. No new widgets needed.

| Screen | File | Work Required |
|--------|------|---------------|
| WalletScreen | `wallet/screens/wallet_screen.dart` | Replace hardcoded `BorderRadius.circular(20/8)` → AppRadii, `Colors.orange` → semantic, hardcoded EdgeInsets → AppSpacing |
| BackgroundProductionSettings | `settings/screens/background_production_settings_screen.dart` | Replace `fontSize:12` → textTheme, minor token alignment |
| NodePeersScreen | `node/screens/node_peers_screen.dart` | Already mostly clean, verify token usage |
| NodeStatusProducedBlocksScreen | `node/screens/node_status_produced_blocks_screen.dart` | Already mostly clean |
| NodeWonSlotsScreen | `node/screens/node_won_slots_screen.dart` | Already mostly clean |
| ProducedBlockDetailsScreen | `node/screens/produced_block_details_screen.dart` | Already mostly clean |

**New widgets needed**: None
**Estimated scope**: Small — token swaps only

---

### Wave 2: High-Impact User-Facing Surfaces (5 screens)
**Theme**: Wallet and transaction screens visible to all users. Requires 2 new DS widgets.

| Screen | File | Work Required |
|--------|------|---------------|
| SendScreen | `wallet/screens/send_screen.dart` | Replace hardcoded colors/fontSize, introduce DS TextField |
| TransactionSuccessScreen | `wallet/screens/transaction_success_screen.dart` | Replace Colors.green/white/fontSize:18, use new ResultPage widget |
| TransactionFailedScreen | `wallet/screens/transaction_failed_screen.dart` | Replace Colors.red/white/fontSize:18, use new ResultPage widget |
| SplashScreen | `splash/screens/splash_screen.dart` | Minor — verify token alignment |
| DappsScreen | `dapps/dapps_screen.dart` | Replace hardcoded EdgeInsets → AppSpacing |

**New widgets needed**:
1. `ResultPage` — success/failure/info full-page layout
2. `TextField` (DS) — wraps AppTextField with ThemeExtension tokens

**Estimated scope**: Medium — 2 new widgets + screen updates

---

### Wave 3: Complex Node Domain (6 screens)
**Theme**: Node screens deeply coupled to FRB types and Riverpod. Requires semantic color strategy for status indicators.

| Screen | File | Work Required |
|--------|------|---------------|
| NodeStatusScreen | `node/screens/node_status_screen.dart` | Replace hardcoded EdgeInsets/BorderRadius/fontSize, standardize metric tiles |
| SlotAssignmentsScreen | `node/screens/slot_assignments_screen.dart` | Replace 5+ hardcoded colors → semantic tokens |
| SlotProductionStatsScreen | `node/screens/slot_production_stats_screen.dart` | Replace Colors.amber/blue/green/red → semantic colors for charts |
| MempoolDetailsScreen | `node/screens/mempool_details_screen.dart` | Replace Colors.orange/fontSize:11 → semantic + textTheme |
| BlockDetailsScreen | `node/screens/block_details_screen.dart` | Verify and align hardcoded values |
| NodeStatusSummaryModal | `node/screens/widgets/node_status_summary_modal.dart` | Replace hardcoded EdgeInsets/BorderRadius → tokens |

**New widgets needed**:
1. `StatusBadge` — colored indicator with icon + label for status states
2. `MetricTile` — standardized data card with icon, title, value

**Estimated scope**: Medium-Large — 2 new widgets + semantic color strategy for node status states

---

### Wave 4: Onboarding & Edge Cases (7 screens)
**Theme**: One-time-use screens with low user impact. Benefits from shared Permission layout.

| Screen | File | Work Required |
|--------|------|---------------|
| ExactAlarmPermission1Screen | `onboarding/screens/exact_alarm_permission1_screen.dart` | Replace Colors.green/orange → semantic, extract shared layout |
| BatteryPermission2Screen | `onboarding/screens/battery_permission2_screen.dart` | Use shared permission layout |
| NotificationPermission3Screen | `onboarding/screens/notification_permission3_screen.dart` | Use shared permission layout |
| OnboardingBatteryCompleteScreen | `onboarding/screens/onboarding_battery_complete_screen.dart` | Use shared result layout |
| WelcomeClaimScreen | `onboarding/screens/welcome_claim_screen.dart` | Replace hardcoded EdgeInsets → AppSpacing |
| WelcomeSetupScreen | `onboarding/screens/welcome_setup_screen.dart` | Minor — verify token alignment |
| ImportApiAccountScreen | `onboarding/screens/import_api_account_screen.dart` | Use DS TextField |

**New widgets needed**:
1. `PermissionPage` — shared layout for permission request screens (could extend ResultPage)

**Estimated scope**: Small-Medium — 1 new widget (or ResultPage variant) + screen updates

---

### Theme Injection Strategy

**Current state**: `DesignSystemTheme` wraps individual widget subtrees; tokens are not yet at app root.

**Recommendation**: Move `DesignSystemTheme.standardExtensions()` to the app-level `MaterialApp.theme.extensions` so ALL screens automatically have access to design system tokens without explicit wrapping. This unblocks Wave 1-4 migration by making tokens globally available.

**Steps**:
1. Add `DesignSystemTheme.standardExtensions()` to `MaterialApp.theme` in app root
2. Remove per-screen `DesignSystemTheme` wrappers (they become redundant)
3. Existing design_tokens.dart constants can be deprecated incrementally as screens adopt ThemeExtension

---

## G. Deprecated Code Cleanup

### Deprecated Screens

| Item | File | Status | Blocker |
|------|------|--------|---------|
| ProducedBlocksScreen | `node/screens/produced_blocks_screen.dart:16` | `@Deprecated('Replaced by EpochPerformanceScreen')` | Verify no remaining routes reference it |

### Deprecated/Superseded Widgets

| Item | File | Superseded By | Blocker |
|------|------|--------------|---------|
| AppButton | `core/widgets/app_button.dart` | DS `Button` | 5 core widgets import `design_tokens.dart`; need to verify no screens still use AppButton directly |
| AppActionButton | `core/widgets/app_action_button.dart` | No direct replacement; low reuse | Check usage count |
| design_tokens.dart | `core/config/design_tokens.dart` | ThemeExtension tokens (AppSpacing, AppRadii, etc.) | 5 core widgets depend on it |
| MaterialTheme (legacy) | `core/config/theme.dart` | `ColorIsExpensiveTheme` | Check if any screen still references MaterialTheme directly |

### Cleanup Dependencies

Before removing deprecated items:
1. **Audit usage of `design_tokens.dart`** — 5 core widgets import it. Migrate those widgets first (Wave 1 prerequisite).
2. **Audit `ProducedBlocksScreen` routes** — ensure no navigation references it. If none, safe to delete.
3. **Audit legacy `MaterialTheme`** — check if any screen or service still imports `core/config/theme.dart` for node_status colors or internal-network theming. Those colors may need to move to `AppSemanticColors`.
