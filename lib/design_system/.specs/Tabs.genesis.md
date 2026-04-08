# Tabs — Genesis Document

> Tracks every design decision from Figma inspection through implementation.
> New sections are appended as the widget evolves.

## Phase 1: Figma Inspection (2026-02-23)

### Source
- **Figma node**: `3012:2400` — Primary tab bar (Type=Fixed, Style=Primary, Configuration=Label only)
- 3 equal-width tabs with active indicator and full-width divider
- Screenshot shows app usage: "Active ②", "Completed ①", "Missed" — challenge filter with inline badge counts

### M3 Component Study
Studied Flutter source to understand the original M3 component:
- `_TabsPrimaryDefaultsM3` (tabs.dart:2665) — tab bar colors, typography, indicator
- `_BadgeDefaultsM3` (badge.dart:449) — badge sizing, colors, shape
- `TabController` (tab_controller.dart:100) — state management pattern
- `TabBarView` (tabs.dart:2068) — PageView-based content switching

M3 dimensions adopted directly: 48dp bar height, 3dp indicator, titleSmall style, 16dp badge height, horizontal 4dp badge padding, outlineVariant 1dp divider.

### Decisions During Inspection

#### Complete tab view, not just a bar
The widget includes both the tab bar AND a PageView content area. This makes it drop-in ready — no separate controller setup needed. Internally manages selection state as a StatefulWidget. The parent only provides `tabs`, `children`, and an optional `onTabChanged` callback.

#### PageView for content switching
M3's TabBarView uses `PageView` internally (a core Flutter widget, not Material). We do the same — it provides native-feeling swipe gesture between tab contents, which is expected behavior on mobile.

#### Fixed + scrollable modes
Two modes via `isScrollable` flag:
- `false` (default): equal-width tabs fill the bar (`Expanded` per tab)
- `true`: natural-width tabs in a `SingleChildScrollView`

This matches M3's `TabAlignment.fill` (fixed) vs `TabAlignment.startOffset` (scrollable) behavior.

#### Badge color: onSurface, not error
M3 badges use `error` (red) — designed for alert notifications. Our badges show neutral filter counts (Active 2, Completed 1), so they use `onSurface` (dark) with `surface` (light) text. StadiumBorder and 16dp height match M3 exactly.

#### Badge inline, not overlaid
M3 positions badges as Stack overlays on icons. Our badges sit inline in the label row — simpler and appropriate for text-based tabs without icons.

#### Indicator: Figma's 2px inset adopted
The 2px horizontal inset on the indicator comes from the Figma design. Flutter's M3 implementation uses `indicatorPadding: EdgeInsets.zero` by default. We adopt the Figma's subtle inset for visual refinement.

#### Internal state, no external controller
M3 exposes `TabController` (ChangeNotifier + AnimationController) for external state coordination. Our widget manages state internally — simpler API, presentation-only-compatible (no providers needed). The `onTabChanged` callback notifies the parent when selection changes.

#### Indicator slide animation in v1
M3 uses elastic animation for indicator movement between tabs. We include this in v1 — the indicator smoothly slides between tabs on both tap and swipe. During swipe, the indicator position tracks the PageView scroll offset in real-time. On tap, it animates over 300ms (M3 `kTabScrollDuration`) with easeInOut curve.

### Non-Exact Mappings
| Element | Figma value | Mapped to | Why this choice |
|---------|------------|-----------|-----------------|
| Indicator top radius | 100px | `full` (999) | Functionally identical for 3dp element |
| Badge color | Dark circle (screenshot) | `onSurface` | M3 uses `error`; ours is neutral count, not alert |

## Phase 2: Implementation (2026-02-23)

### Architecture
- `StatefulWidget` — manages `_selectedIndex`, `_pageController`, and `_pagePosition`
- Indicator animation driven by `PageController.page` — no separate `AnimationController` needed
- `PageController.addListener` tracks fractional page position on every scroll tick
- Tab taps call `PageController.animateToPage(duration: AppAnimation.complex, curve: easeInOut)`
- Label color snaps at swipe midpoint via `_pagePosition.round()` for natural feel

### Decisions During Implementation

#### PageController as animation driver (simpler than AnimationController)
The spec called for `AnimationController` + `SingleTickerProviderStateMixin`. During implementation, discovered that `PageController.page` already provides a fractional position that updates on every scroll frame. Using it directly as the indicator offset driver avoids duplicating animation state. The `PageView.animateToPage` method handles the tap animation with the same 300ms/easeInOut curve. Result: same visual behavior, fewer moving parts.

#### Fixed-mode indicator uses LayoutBuilder + Positioned
In fixed mode, `LayoutBuilder` provides the total tab bar width. Each tab is `totalWidth / tabCount`. The indicator `Positioned.left` = `_pagePosition * tabWidth + 2px`. This arithmetic approach avoids `GlobalKey` measurement complexity and works perfectly for equal-width tabs.

#### Scrollable-mode indicator snaps (no slide)
In scrollable mode, tabs have natural widths that vary. Implementing smooth indicator slide would require measuring each tab's position via `GlobalKey` and interpolating between them. For v1, the scrollable indicator snaps to the selected tab. Fixed mode (the Figma default) gets the full slide animation.

#### Label colors: onSurface/outline, not primary/onSurfaceVariant
M3 defaults use `primary` (active) and `onSurfaceVariant` (inactive). In the "Color is Expensive" theme, `primary` (#252627) and `onSurfaceVariant` (#44474D) are both dark gray — visually nearly identical. Changed to `onSurface` (#1B1B1B, active) and `outline` (#74777E, inactive) for a much larger lightness gap. `onSurface` is the canonical text color for readable content; `outline` signals structural/navigational elements. Labels snap at swipe midpoint via `_selectedIndex.round()` — no cross-fade needed.

### Token Mapping
| Figma Value | Design System Token | Notes |
|-------------|-------------------|-------|
| 48dp tab bar height | `48.0` (M3 `kTextTabBarHeight`) | Structural constant |
| 3dp indicator | `3.0` (M3 indicator weight) | Structural constant |
| 16dp badge height | `16.0` (M3 `largeSize`) | Structural constant |
| 1dp divider | `1.0` + `outlineVariant` | Structural constant + semantic color |
| 2px indicator inset | `2.0` hardcoded | Deliberate Figma adoption |
| 16px horizontal padding | `spacing.space16` | Token |
| 4px label-badge gap | `spacing.space4` | Token |
| 4px badge horizontal padding | `spacing.space4` | Token |
| Indicator top radius | `radii.full` (999) | Nearest snap from 100px |
| Active label color | `colorScheme.onSurface` | Deliberate: `primary` ≈ `onSurfaceVariant` in CIE theme, insufficient gap |
| Inactive label color | `colorScheme.outline` | Deliberate: much larger lightness gap vs `onSurfaceVariant` |
| Badge background | `colorScheme.onSurface` | Deliberate deviation from M3 `error` |
| Badge text | `colorScheme.surface` | Semantic |
| Label style | `textTheme.titleSmall` | Exact M3 match |
| Badge text style | `textTheme.labelSmall` | Exact M3 match |
| Animation duration | `AppAnimation.complex` (300ms) | Token (M3 `kTabScrollDuration`) |

#### Badge active/inactive color treatment
Badges originally used `onSurface` (dark) background regardless of tab state. This made inactive tab badges more visually prominent than their labels, breaking the visual hierarchy — the label faded to `outline` but the badge stayed dark. Changed to:
- **Active tab badge**: `onSurface` bg + `surface` text (dark, prominent — unchanged)
- **Inactive tab badge**: `outline` bg + `surface` text (lighter, matching inactive label tone)

Now both label and badge use the `outline` color family on inactive tabs, so the entire tab fades together as a unit.

### Golden Reference
- **Golden files**: `test/design_system/goldens/tabs_fixed_badges.png`, `tabs_fixed_no_badges.png`, `tabs_second_selected.png`, `tabs_scrollable.png`
- Rendered with light theme, 360x400 viewport

## Phase 3: M3 Migration (2026-02-24)

### Decision
Adopted selective M3 policy. Hand-managed `PageController` + indicator sync via `_pagePosition` tracking was complex (303 LOC) and lacked keyboard navigation and screen reader semantics.

### Migration
Replaced manual tab bar + `PageView` with M3 `TabBar` + `TabBarView` driven by `TabController`. Badge color animation preserved via `AnimatedBuilder` listening to `TabController`. Visual appearance controlled by `tabBarTheme` in `ColorIsExpensiveTheme`.

### What changed
- Gained: ripple feedback, focus management, keyboard navigation (arrow keys), screen reader semantics, proper indicator animation (elastic spring)
- LOC: 303 → 150 (50% reduction)
- Removed: `_buildFixedTabBar`, `_buildScrollableTabBar`, manual `LayoutBuilder` indicator positioning, `_pagePosition` tracking, `_indexIsChanging` guard
- `SingleTickerProviderStateMixin` added for `TabController` vsync

### What stayed
- Widget name: still `Tabs`, not `TabBar`
- API preserved: `Tabs(tabs:, children:, initialIndex:, onTabChanged:, isScrollable:)` unchanged
- Badge treatment: inline badge with active/inactive color (onSurface/outline), not M3 error badge
- Divider: `outlineVariant` 1dp (from `tabBarTheme.dividerColor`)
- Indicator: `primary` color (from `tabBarTheme.indicatorColor`)

## Composition

**Use when:** Switching between content sections within a single screen (e.g., challenge categories, leaderboard views).
**Parent containers:** PSL `surfacePinnedSlivers` (pinned at surface junction in `nestedBody` mode), or standalone in any layout.
**Pair with:** `TabBarView` / `nestedBody` for independently scrollable tab content, `ParallaxSurfaceLayout` for PSL integration.
**Anti-patterns:** Don't use for top-level navigation — use `BottomNav`. Don't use inside a non-scrollable layout if content per tab can overflow.
**Screen example:** `lib/features/challenges/screens/challenges_screen.dart` — category tabs pinned at PSL surface with `nestedBody`
