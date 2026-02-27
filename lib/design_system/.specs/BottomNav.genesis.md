# BottomNav — Genesis Document

> Tracks every design decision from Figma inspection through implementation.
> New sections are appended as the widget evolves.

## Phase 1: Figma Inspection (2026-02-23)

### Source
- **Figma node**: `2994:2451` — Bottom navigation bar
- 5-item bottom nav: icon + label per item, pill-shaped active indicator behind selected icon, badge support, disabled-item treatment
- Items: Challenges, Apps, Wallet, Node, Settings

### M3 Component Study
Studied Flutter source `_NavigationBarDefaultsM3` to understand the original M3 component:
- Height: 80dp
- Indicator: 64×32, StadiumBorder, `secondaryContainer`
- Icon size: 24dp
- Icon color (selected): `onSecondaryContainer`
- Icon color (unselected): `onSurfaceVariant`
- Label style: `labelMedium`
- Label color (selected): `onSurface`
- Label color (unselected): `onSurfaceVariant`
- Label padding top: 4dp

### Decisions During Inspection

#### Presentation-only StatelessWidget
Unlike the Tabs widget (which manages internal state for PageView coordination), BottomNav is a pure presentation widget. The parent manages `selectedIndex` and receives taps via `onItemSelected`. This keeps the widget simple and matches the pattern used by screens that already manage navigation state.

#### No elevation — top border instead
M3 NavigationBar uses surface tint + elevation for visual separation. The Figma design shows a white surface with a 1px `outlineVariant` top border — consistent with the app's flat visual language and the HomeScreen's existing pattern.

#### No ripple / overlay
M3 uses InkWell with ripple on nav items. We use GestureDetector for a clean tap with no splash — consistent with the design system's approach in other widgets.

#### Always show labels
M3 supports `NavigationDestinationLabelBehavior` with options to hide labels on unselected items. The Figma design always shows labels, so we hardcode this behavior.

#### Badge uses error color
M3 badges on NavigationBar use `error` (red) background — designed for notification counts that demand attention. Unlike Tabs (where badges show neutral filter counts), nav badges represent unread/action-required counts, so we adopt the M3 `error`/`onError` color pair.

#### Disabled item treatment
Items with `enabled: false` render at 50% opacity and do not respond to taps. This matches the Figma design's disabled treatment.

#### Animated pill indicator
The active indicator uses `AnimatedContainer` with `AppAnimation.normal` (150ms) duration and StadiumBorder shape. The pill expands from 0 to 64dp width when selected, creating a subtle scale-in effect.

### Non-Exact Mappings
| Element | Figma value | Mapped to | Why this choice |
|---------|------------|-----------|-----------------|
| Indicator shape | Rounded rectangle | `StadiumBorder` | M3 spec uses StadiumBorder for nav indicator |
| Badge pill shape | Circle/stadium | `StadiumBorder` | Consistent with Tabs badge pattern |
| Top border | 1px line | `BorderSide(color: outlineVariant)` | Semantic color, same as Tabs divider |

## Phase 2: Implementation (2026-02-23)

### Architecture
- `StatelessWidget` — no internal state, fully controlled by parent
- `DecoratedBox` for surface + top border (avoids `Container` overhead)
- `SafeArea(top: false)` for bottom safe area only (notch devices)
- `Row` of `Expanded` items for equal-width distribution
- `AnimatedContainer` for pill indicator transition

### Decisions During Implementation

#### DecoratedBox over Container
Used `DecoratedBox` for the outermost wrapper since we only need decoration (background + border), not padding or constraints. More efficient than `Container`.

#### Opacity widget for disabled state
Used `Opacity(opacity: 0.5)` for disabled items rather than computing individual alpha values for icon + label. Simpler and applies uniformly to the entire item including badge.

#### Badge positioned top-right of indicator zone
Badge is `Positioned(top: 2, right: 0)` within the 64×32 indicator zone. This places it at the top-right of the icon area, overlapping the indicator pill slightly — matching M3 NavigationBar badge placement.

### Token Mapping
| Figma Value | Design System Token | Notes |
|-------------|-------------------|-------|
| 80dp height | `80.0` (M3 NavigationBar height) | Structural constant |
| 64×32 indicator | `64.0` × `32.0` (M3 indicator) | Structural constant |
| 24dp icon | `24.0` (M3 icon size) | Structural constant |
| 16dp badge height | `16.0` (M3 `largeSize`) | Structural constant |
| 4dp label gap | `spacing.space4` | Token |
| 4dp badge horizontal padding | `spacing.space4` | Token |
| Indicator shape | `StadiumBorder()` | M3 spec |
| Indicator color | `colorScheme.secondaryContainer` | Semantic |
| Icon color (selected) | `colorScheme.onSecondaryContainer` | Semantic |
| Icon color (unselected) | `colorScheme.onSurfaceVariant` | Semantic |
| Label style | `textTheme.labelMedium` | Exact M3 match |
| Label color (selected) | `colorScheme.onSurface` | Semantic |
| Label color (unselected) | `colorScheme.onSurfaceVariant` | Semantic |
| Badge background | `colorScheme.error` | M3 badge default |
| Badge text | `colorScheme.onError` | M3 badge default |
| Badge text style | `textTheme.labelSmall` | Exact M3 match |
| Background | `colorScheme.surface` | Semantic |
| Top border | `colorScheme.outlineVariant` | Semantic |
| Animation duration | `AppAnimation.normal` (150ms) | Token |

## Phase 3: Material Symbols Icons + Fill Behavior (2026-02-23)

### Switch to `material_symbols_icons` package

Replaced Flutter built-in `Icons.*_sharp` with exact Material Symbols Sharp icons from `package:material_symbols_icons/symbols.dart`. The built-in `Icons` class lacks several glyphs used in Figma (`cards_star`, `action_key`), which forced fallback icons.

Exact icon mapping:
| Item | Symbols icon |
|------|-------------|
| Challenges | `Symbols.cards_star_sharp` |
| Apps | `Symbols.action_key_sharp` |
| Wallet | `Symbols.account_balance_wallet_sharp` |
| Node | `Symbols.check_circle_sharp` |
| Settings | `Symbols.settings_sharp` |

### Fill-based active/inactive state

Removed the redundant `activeIcon` field from `BottomNavItem`. Active/inactive is now controlled by the `Icon` widget's variable-font `fill` axis:
- **Selected**: `fill: 1` (filled glyph)
- **Unselected**: `fill: 0` (outline glyph)

All icons also use `weight: 300` to match Figma's weight setting, consistent with ChallengeCard icons.

### Color system unchanged

Active/inactive colors remain `primary` / `outline`, matching the Tabs widget color system.

## Phase 4: M3 Migration (2026-02-24)

### Decision
Adopted selective M3 policy. Navigation needs real semantics for screen readers. Migrated to M3 `NavigationBar`.

### Migration
Replaced manual `DecoratedBox` + `Row` + `GestureDetector` layout with `NavigationBar` + `NavigationDestination` destinations. Icon fill/weight controlled via `navigationBarTheme.iconTheme` state resolution. Badge uses M3 `Badge` widget. Pill indicator suppressed via `indicatorColor: transparent`. Top border preserved via outer `DecoratedBox` wrapper.

### What changed
- Gained: ripple feedback, focus management, keyboard navigation, screen reader semantics (route labels, selection state)
- LOC: 171 → 113 (34% reduction)
- Removed: manual icon zone layout, `AnimatedContainer` pill, per-item `GestureDetector`
- Badge: switched from manual `Container` + `StadiumBorder` to M3 `Badge` widget

### What stayed
- Widget name: still `BottomNav`, not `NavigationBar`
- API preserved: `BottomNav(items:, selectedIndex:, onItemSelected:)` unchanged
- No pill indicator: active state is color-only (primary/outline)
- Top border: `outlineVariant` `BorderSide`
- Disabled treatment: 50% opacity via `Opacity` widget
- Presentation-only: no providers
