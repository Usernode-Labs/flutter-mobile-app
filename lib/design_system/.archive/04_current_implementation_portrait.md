# Current Implementation Portrait

> Archived from Intent workspace note `0ce8a7e3-e868-4eff-9db4-4ecf780ccf3a` (Feb 2026).
> Full unabridged research content.

---

This note synthesizes findings from the M3 Theme Audit and UI Components Audit into a structure that maps directly onto the First-Principles Design (sections 2A–2E), enabling side-by-side gap analysis in Step 4.

**No new source file analysis was performed.** All data comes from the two audit notes.

---

## 3A. Current Color Architecture (maps to 2A: Color Architecture — The Full Role Map)

*Sources: M3 Theme Audit §A1–A8, §B1–B4, Appendix*

### M3 Role Family Assignments

The current implementation assigns every M3 ColorScheme role. The defining characteristic: **all three key roles (primary, secondary, tertiary) are achromatic.**

| M3 Role Family | Current Assignment | Character |
|---|---|---|
| **primary** / onPrimary | `#252627` / `#FFFFFF` | Near-black ink, zero chroma. "The attention locker." Highest-contrast CTA role. *(Audit §A1)* |
| **primaryContainer** / onPrimaryContainer | Part of achromatic tonal palette | Muted primary container for tonal buttons |
| **secondary** / onSecondary | `#5C5E64` / `#FFFFFF` | Cool-grey from neutral-variant palette. Structural emphasis without hue. *(Audit §A2)* |
| **secondaryContainer** / onSecondaryContainer | `#E1E2E8` (derived) | Used by M3's `FilledTonalButton` and `NavigationBar` indicator — renders as grey |
| **tertiary** / onTertiary | `#757575` / implicit | **Ghost role.** Pure neutral grey. Deliberately starved of contrast. "Trap role" forcing developers to `AppSemanticColors`. *(Audit §A3)* |
| **tertiaryContainer** / onTertiaryContainer | `#F5F5F5` / implicit | Nearly identical to `surface` — container is ~ΔY 6 from surface (practically invisible) |
| **error** / onError | `#BD0F19` / `#FFFFFF` | **Only chromatic M3 role.** Slightly more saturated than M3 default (`#B3261E`). APCA-verified. *(Audit §A4)* |
| **errorContainer** / onErrorContainer | `#FFBFA9` / implicit | Warmer/more orange-tinted than M3's `#F9DEDC` |
| **surface** | `#F5F5F5` (T96) | Grey scaffold — 3 tonal steps darker than M3 default (T99). Pure achromatic, no primary tint. *(Audit §A5)* |
| **surfaceDim** / **surfaceBright** | Present in scheme | Part of the 5-level gradient |
| **surfaceContainerLowest** → **surfaceContainerHighest** | `#FFFFFF` → `#E2E2E2` | Full 5-level gradient exists, but in practice only 2 levels used (see Surface Hierarchy below). *(Audit §A5)* |
| **onSurface** / **onSurfaceVariant** | `#1B1B1B` / `#44474D` | Text hierarchy: near-black primary text, mid-grey secondary text |
| **outline** / **outlineVariant** | `#74777E` / `#C4C6CC` | Nearly identical to M3 defaults. Cool-grey lean. Used for structural borders. *(Audit §A6)* |
| **inverseSurface** / **inversePrimary** | `#303030` / `#C5C6C8` | Inverse for snackbars/tooltips. `inversePrimary` is achromatic (consistent). *(Audit §A7)* |
| **surfaceTint** | `Colors.transparent` | **Explicitly killed** on all component themes. Disables M3's entire tonal elevation system. *(Audit §B2)* |

### Surface Hierarchy in Practice

*(Source: M3 Theme Audit §B1–B4)*

The implementation collapses M3's 5-level tonal surface system into a **two-tier model**:

| Tier | Role | Color | Used By |
|------|------|-------|---------|
| **Grey scaffold** | `surface` | `#F5F5F5` | Page backgrounds, Scaffold |
| **White content** | `surfaceContainerLowest` | `#FFFFFF` | Cards, NavigationBar, BottomSheet, Dialog, Drawer |

Separation between tiers is via `outlineVariant` borders, not elevation. All content-level components land on `surfaceContainerLowest` — a `NavigationBar` and a `Card` are visually identical (both white, both flat). *(Audit §B1)*

The full 5-level surface container gradient is defined in the ColorScheme but **not actively used** by component themes. Individual widgets could opt into finer tonal hierarchy if needed.

`surfaceTintColor: Colors.transparent` is set on: AppBar, NavigationBar, BottomSheet, Card, Dialog, Drawer — killing M3's tonal elevation system entirely. *(Audit §B2)*

### Dark Mode Status

*(Source: M3 Theme Audit §E4)*

- `ColorIsExpensiveTheme` has **complete dark scheme support** (`darkScheme()`, `dark()` methods)
- Dark surface at `#1B1B1B`, dark primary at `#D4D4D6`, dark secondary at `#C8CAD0`, dark tertiary at `#B8B8B8`
- **But dark mode is never activated at the design system boundary.** Feature screens hardcode `.light()`. When the user toggles dark mode, the app root switches but design system content stays light — creating a visual inconsistency (dark chrome + light content area).

### Contrast Cascade

*(Source: M3 Theme Audit §A3, §A8)*

Three contrast levels exist: standard, medium, high. The ghost tertiary progressively restores visibility in medium and high contrast variants — acting as an accessibility escape valve. All color pairs are APCA-verified (body text Lc ≥ 90, accents Lc ≥ 60, borders Lc ≥ 30), but **not WCAG 2.x verified** (APCA is draft in WCAG 3.0). *(Audit §A8)*

---

## 3B. Current Semantic Color Architecture (maps to 2B: Semantic Color Extension Architecture)

*Sources: M3 Theme Audit §D3, Appendix Semantic Colors table*

### The 4 Semantic Groups

The semantic color system lives in `AppSemanticColors` — a `ThemeExtension<AppSemanticColors>` that acts as the **only sanctioned path to chromatic color** in the design system.

| Group | Hue | Color | Container | Purpose |
|-------|-----|-------|-----------|---------|
| **technical** | Blue | `#0055D9` | `#D3D9FF` | Technical/system-related features |
| **flash** | Amber | `#875300` | `#FFD87B` | Flash/attention/warning states |
| **community** | Green | `#146D32` | `#B6F0BE` | Community/social features |
| **success** | Green | `#1A6D23` | `#BAF1B4` | Success/completion states |

*(Source: M3 Theme Audit Appendix — Semantic Colors (Light))*

### Structure: 4-Role Pattern

Each semantic group follows the M3 4-role pattern:
- `color` / `onColor` / `colorContainer` / `onColorContainer`

This mirrors M3's own role structure (primary/onPrimary/primaryContainer/onPrimaryContainer) and is functionally equivalent to M3's "custom colors" or "extended colors" concept. *(Audit §D3)*

Four brightness/contrast variants exist: `light()`, `dark()`, `mediumContrast()`, `highContrast()`.

### Access Pattern

Widgets access semantic colors via:
```dart
Theme.of(context).extension<AppSemanticColors>()!
```

### Coverage

*(Source: UI Components Audit §A, §C)*

**Screens/widgets that USE semantic colors:**
- All 4 challenge screens (ChallengesScreen, ChallengeDetailScreen, EpochPerformanceScreen, ChallengesDelegates)
- HomeScreen
- LeaderboardScreen
- Design system widgets: ChallengeCard, ChallengeActivitySummary, ChallengeRewardCard, ChallengeCategoryIcon, ScoreHeader

**Screens that DON'T use semantic colors (but need chromatic color):**
- Wallet screens: Use hardcoded `Colors.green`, `Colors.red`, `Colors.orange` for transaction status
- Node screens: Use hardcoded `Colors.amber`, `Colors.blue`, `Colors.green`, `Colors.red`, `Colors.orange` for status indicators and chart colors
- Onboarding screens: Use hardcoded `Colors.green`, `Colors.orange` for permission status

These unmigrated screens use raw `Colors.*` constants instead of going through `AppSemanticColors`, bypassing the chromatic budget entirely. *(UI Components Audit §E1)*

---

## 3C. Current Theme Configuration (maps to 2C: Theme Configuration Architecture)

*Sources: M3 Theme Audit §E1–E5*

### Dual Theme Architecture

Two theme systems coexist:

| Theme | Class | Location | Character |
|-------|-------|----------|-----------|
| **Legacy** | `MaterialTheme` | `lib/core/config/theme.dart` | Chromatic: blue primary (`#2633C5`), cyan secondary (`#00B6F0`), green tertiary (`#4CAF50`). Applied at app root via `main.dart`. |
| **Design system** | `ColorIsExpensiveTheme` | `lib/design_system/theme/` | Achromatic: near-black primary (`#252627`), ghost tertiary (`#757575`). Applied locally at feature boundaries via `Theme()` widget. |

*(Source: M3 Theme Audit §E1)*

### Theme Injection Pattern

At feature boundaries (currently only challenges), a `Theme()` widget overrides the inherited legacy theme:

```dart
Theme(
  data: ColorIsExpensiveTheme(textTheme).light().copyWith(
    extensions: DesignSystemTheme.standardExtensions(
      semanticColors: AppSemanticColors.light(),
    ),
  ),
  child: Builder(builder: (context) => _buildBody(context)),
)
```

This creates a full `ThemeData` from `ColorIsExpensiveTheme`, adds all 7 ThemeExtensions + `AppSemanticColors` via `copyWith`, and uses `Builder` to ensure children see the new theme. *(Audit §E2)*

### Identified Risks

*(Source: M3 Theme Audit §E3)*

| Risk | Severity | Description |
|------|----------|-------------|
| **Sibling leak** | MEDIUM | If a feature screen doesn't wrap with `ColorIsExpensiveTheme`, its design system widgets render against the legacy blue theme. |
| **Extension absence** | HIGH | The legacy `MaterialTheme` at app root has **no ThemeExtensions**. Any widget calling `Theme.of(context).extension<AppSpacing>()!` outside a design system boundary throws a null assertion error. |
| **Dark mode gap** | HIGH | Feature boundaries hardcode `.light()`. App root supports dark toggle, but design system content stays light. *(Audit §E4)* |

### Token Registration

*(Source: M3 Theme Audit §D1)*

7 custom `ThemeExtension` classes registered via `DesignSystemTheme.standardExtensions()`:
- `AppSpacing` (4–48dp, exact M3 4dp grid match)
- `AppRadii` (8–999, close to M3 shape scale)
- `AppElevation` (0/1/2/4/8 — diverges from M3's 0/1/3/6/8/12)
- `AppOpacity` (0.08–0.40, partial M3 state layer match)
- `AppSizing` (icons 20–32, buttons 40–56, aligned on M3 key values)
- `AppAnimation` (100–300ms, partial M3 motion match)
- `AppSemanticColors` (the chromatic escape hatch)

Token values alignment with M3: spacing is exact match, radii are close (xLarge 24 vs M3's extra-large 28), elevation diverges (missing levels 3 and 6), opacity partially matches, sizing aligns on key values, animation partially matches. *(Audit §D2)*

### Migration Path

*(Source: M3 Theme Audit §E5)*

A 5-step migration plan exists: (1) add ThemeExtensions to app root, (2) add AppSemanticColors to app root, (3) migrate screens one-by-one, (4) remove local Theme() wrappers, (5) delete legacy MaterialTheme.

---

## 3D. Current Component Application (maps to 2D: Component Color Application Strategy)

*Sources: M3 Theme Audit §C1–C9, UI Components Audit §A–B*

### 9 Component Theme Overrides

The `ColorIsExpensiveTheme` overrides 9 M3 component themes. The overriding pattern is consistent: **flatten elevation, kill surface tint, push everything to `surfaceContainerLowest` (white).**

*(Source: M3 Theme Audit §C1–C9)*

**Navigation:**
| Component | Key Overrides | M3 Compatibility |
|-----------|--------------|-----------------|
| **AppBar** (C1) | `scrolledUnderElevation: 0`, `surfaceTintColor: transparent` | Mostly yes — kills scroll feedback but preserves surface/onSurface colors |
| **NavigationBar** (C2) | `backgroundColor: surfaceContainerLowest`, `surfaceTintColor: transparent`. No `indicatorColor` override — M3 default (`secondaryContainer`) applies, rendering as grey `#E1E2E8` | No — 2 levels lower than M3 default |

**Containment:**
| Component | Key Overrides | M3 Compatibility |
|-----------|--------------|-----------------|
| **Card** (C4) | `elevation: 0`, `surfaceTintColor: transparent`, `outlineVariant` border, r16 | Yes — equivalent to M3 Outlined Card variant (M3 uses r12) |
| **Dialog** (C5) | `backgroundColor: surfaceContainerLowest`, `elevation: 0`, r24 | No — 4 levels lower, no shadow (scrim provides separation). r24 vs M3's r28 |
| **BottomSheet** (C3) | `backgroundColor: surfaceContainerLowest`, `elevation: 0` | No — 1 level lower than M3 default |
| **Drawer** (C7) | `backgroundColor: surfaceContainerLowest`, `elevation: 0` | No — 1 level lower |

**Structural:**
| Component | Key Overrides | M3 Compatibility |
|-----------|--------------|-----------------|
| **Divider** (C6) | `color: outlineVariant`, `thickness: 1`, `space: 1` | Mostly — space: 1 vs M3's default space: 16 |
| **ListTile** (C9) | `dense: true`, `visualDensity: compact`, `bodyMedium` title (vs M3's bodyLarge), r12 shape | No — double-compaction may push below 48dp touch target |
| **SnackBar** (C8) | `behavior: floating`, r12 | Mostly — floating is M3-recommended, r12 is minor visual preference |

### Design System Widget Color Usage

*(Source: UI Components Audit §A)*

18 design system widgets in `lib/design_system/src/`. All use ThemeExtension tokens and are presentation-only. Key color patterns:

- **Achromatic structural use**: Widgets like Button, TopAppBar, BottomNav, Tabs use `colorScheme` roles (primary, onSurface, outlineVariant) — rendering achromatically per the theme
- **Chromatic semantic use**: ChallengeCard, ChallengeRewardCard, ChallengeActivitySummary, ChallengeCategoryIcon, ScoreHeader use `AppSemanticColors` for category-specific chromatic color (technical blue, flash amber, community green)
- **M3-backed components**: Button wraps `FilledButton`/`OutlinedButton`, BottomNav wraps `NavigationBar`, Tabs wraps `TabBar` — leveraging M3 component behavior

### Legacy/Uncovered Screen Color Usage

*(Source: UI Components Audit §B, §E)*

12 core widgets exist with mixed patterns:
- **Legacy token users** (5 widgets): Import `design_tokens.dart` constants (kSpace8, kBorderRadiusLarge, etc.) — flat constants, not ThemeExtensions
- **Provider-coupled** (3 widgets): `AppAppBar`, `AppDrawer`, `NodeStatusIcon` — ConsumerWidgets with provider dependencies, violating presentation-only principle
- **Hardcoded everything** (4 widgets): `FpsMonitor`, `ProducedBlockCard`, `WonSlotItem`, `AppProgressBar` — use raw `Colors.*`, hardcoded sizes, hardcoded radii

Across 25 unmigrated screens (of 31 total), color application is ad-hoc:
- 6 screens already fully migrated to design system (challenges + home + leaderboard)
- Wallet screens (4): Mix of DS tokens and hardcoded colors/sizes
- Node screens (11): Most complex — hardcoded status colors, FRB-coupled types, deeply nested provider dependencies
- Onboarding screens (7): Mostly DS tokens with scattered hardcoded colors
- Other (3): Splash, DApps, Settings — minor cleanup needed

---

## 3E. Current Escape Hatches (maps to 2E: The Escape Hatch Taxonomy)

*Sources: UI Components Audit §E (Anti-Pattern Catalog)*

### Sanctioned Paths to Chromatic Color

1. **Error role** — M3's built-in `colorScheme.error` (`#BD0F19`). Always chromatic. Used correctly where errors need signaling.

2. **AppSemanticColors** — The intended "chromatic gatekeeper." 4 semantic groups (technical/flash/community/success) accessed via `Theme.of(context).extension<AppSemanticColors>()!`. Used by all 18 design system widgets and 6 migrated screens.

### Unsanctioned Paths (Anti-Patterns)

*(Source: UI Components Audit §E1–E4)*

**1. Hardcoded Colors — 16 instances across 8 files:**

| Color | Instances | Files | Should Be |
|-------|-----------|-------|-----------|
| `Colors.green` | 3 | won_slot_item, slot_production_stats, exact_alarm_permission1 | `semantic.success.color` |
| `Colors.red` | 2 | won_slot_item, slot_production_stats | `colorScheme.error` |
| `Colors.orange` | 4 | won_slot_item, slot_assignments, mempool_details, wallet, exact_alarm_permission1 | `semantic.flash.color` |
| `Colors.amber` | 1 | slot_production_stats | `semantic.flash.color` |
| `Colors.blue` | 1 | slot_production_stats | `semantic.technical.color` |
| `Colors.white` | 2 | transaction_failed, transaction_success | `colorScheme.onPrimary` |
| `Colors.black87` | 1 | slot_assignments | `colorScheme.onSurface` |
| `Colors.grey.shade300` | 1 | slot_assignments | `colorScheme.outlineVariant` |
| `Colors.greenAccent` | 1 | fps_monitor (debug) | N/A (debug overlay) |

**2. Hardcoded Font Sizes — 10 instances across 9 files:**

`fontSize: 9`, `fontSize: 10`, `fontSize: 11` (×3), `fontSize: 12`, `fontSize: 16`, `fontSize: 18` (×3) — all have `textTheme` equivalents (`labelSmall`, `bodySmall`, `bodyLarge`, `titleLarge`). *(UI Components Audit §E2)*

**3. Legacy Token Imports — 5 core widgets:**

`app_action_button.dart`, `app_button.dart`, `app_card.dart`, `app_bottom_sheet.dart`, `app_text_field.dart` all import `design_tokens.dart` (flat constants) instead of using ThemeExtension tokens. *(UI Components Audit §E3)*

**4. Hardcoded Layout Values — 8 instances across 6 files:**

`BorderRadius.circular(2/4/8/12/20)` and `EdgeInsets.all(20)` instead of `AppRadii` and `AppSpacing` tokens. *(UI Components Audit §E4)*

### Quantification

| Escape Hatch Type | Sanctioned | Unsanctioned | Total |
|-------------------|-----------|-------------|-------|
| Chromatic color | 2 paths (error + semantic) | 16 hardcoded Colors.* instances in 8 files | 16 leaks |
| Typography | textTheme (used by DS widgets) | 10 hardcoded fontSize instances in 9 files | 10 leaks |
| Token access | ThemeExtension (used by DS widgets) | 5 legacy design_tokens.dart imports | 5 leaks |
| Layout values | AppSpacing + AppRadii | 8 hardcoded radius/padding instances in 6 files | 8 leaks |
| **Total** | **Fully sanctioned in 6/31 screens** | **39 anti-pattern instances across ~15 files** | **39 leaks** |

The unsanctioned color path accounts for **16 of 39 total leaks** (41%) — chromatic color leaking through raw `Colors.*` constants is the single largest anti-pattern category. All 16 instances map cleanly to existing sanctioned alternatives (semantic colors or colorScheme roles).

### Provider Coupling (Structural Anti-Pattern)

*(Source: UI Components Audit §E5)*

3 core widgets (`AppAppBar`, `AppDrawer`, `NodeStatusIcon`) are `ConsumerWidget`/`ConsumerStatefulWidget` — they carry Riverpod provider dependencies, violating the design system's presentation-only principle. These can't be migrated to the design system without first extracting their state dependencies to the screen layer.
