# Theme Architecture

How the design system's theme is constructed, wired, and overridden.

Source files: [`color_is_expensive_theme.dart`](../theme/color_is_expensive_theme.dart), [`design_system_theme.dart`](../theme/design_system_theme.dart).

---

## ColorScheme Construction

The `ColorScheme` is **manually specified** — not generated via `ColorScheme.fromSeed()`.

**Why manual over fromSeed:**
- `fromSeed()` with an achromatic seed introduces trace chroma from HCT color space conversion — invisible but measurable.
- Manual specification gives exact control over every grey, ensuring zero unwanted tint.
- Every color pairing is APCA-verified. The pipeline needs exact values, not generated approximations.
- ~45 roles change rarely (theme redesigns, not feature work), so the maintenance burden is bounded.

**Achromatic seed strategy** (`color_is_expensive_theme.dart:L21-70`):

| Role | Light Value | Character |
|------|-------------|-----------|
| `primary` | `#252627` | Near-black ink. The "attention locker." Zero chroma. |
| `secondary` | `#5C5E64` | Cool-grey from neutral-variant palette. Structural emphasis. |
| `tertiary` | `#757575` | **Ghost role.** Pure neutral. Barely clears APCA Lc 60. Trap that forces use of `AppSemanticColors`. |
| `error` | `#BD0F19` | Only chromatic M3 role. Signal red. |
| `surface` | `#F5F5F5` (T96) | Grey scaffold — 3 tonal steps darker than M3 default (T99). |
| `surfaceContainerLowest` | `#FFFFFF` | White content layer — cards, sheets, nav bars. |

**APCA verification thresholds:** body text Lc >= 90, accents Lc >= 60, borders Lc >= 30. All pairings verified across standard, medium, and high contrast schemes.

---

## ThemeExtension Registration

Extensions are wired via `DesignSystemTheme.standardExtensions()` (`design_system_theme.dart:L45-56`):

```dart
static List<ThemeExtension> standardExtensions({
  AppSemanticColors? semanticColors,
}) => [
  AppSpacing.standard(),
  AppRadii.standard(),
  AppElevation.standard(),
  AppOpacity.standard(),
  AppSizing.standard(),
  AppAnimation.standard(),
  if (semanticColors != null) semanticColors,
];
```

**Current wiring** — at feature boundaries via `Theme()` widget + `copyWith`:
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

**Ideal wiring** — single root at `MaterialApp`:
```dart
MaterialApp(
  theme: buildTheme(Brightness.light),     // ThemeData + all extensions
  darkTheme: buildTheme(Brightness.dark),  // ThemeData + all extensions
  themeMode: <user preference or system>,
)
```

Access in widgets: `Theme.of(context).extension<T>()!` (e.g., `AppSpacing`, `AppRadii`, `AppSemanticColors`).

---

## Component Theme Overrides

`ColorIsExpensiveTheme.theme()` (`color_is_expensive_theme.dart:L335-426`) overrides 9 M3 component themes. The pattern: **flatten elevation, kill surface tint, push content surfaces to white.**

| Component | Key Override | What It Controls |
|-----------|-------------|-----------------|
| **AppBar** | `scrolledUnderElevation: 0`, `surfaceTintColor: transparent` | Kills M3's tonal shift on scroll. Background stays `surface` (grey). |
| **NavigationBar** | `backgroundColor: surfaceContainerLowest`, `elevation: 0` | White nav bar on grey scaffold (2 levels lower than M3 default). |
| **BottomSheet** | `backgroundColor: surfaceContainerLowest`, `elevation: 0` | White sheet on grey page. |
| **Card** | `surfaceContainerLowest`, `elevation: 0`, `outlineVariant` border, r16 | Outlined card variant — border separation, not shadow. |
| **Dialog** | `surfaceContainerLowest`, `elevation: 0`, r24 | Flat white dialog. Scrim provides separation. |
| **Divider** | `outlineVariant`, `thickness: 1`, `space: 1` | Structural separator. Minimal space (1px vs M3's default 16px). |
| **Drawer** | `surfaceContainerLowest`, `elevation: 0` | White panel, flat. |
| **SnackBar** | `floating`, r12 | M3-recommended floating behavior. |
| **ListTile** | `dense: true`, `visualDensity: compact`, `bodyMedium` title, r12 | Compact density. Known issue: double-compaction may push below 48dp touch target. |

All 6 surface-bearing components (`AppBar`, `NavigationBar`, `BottomSheet`, `Card`, `Dialog`, `Drawer`) set `surfaceTintColor: Colors.transparent` — disabling M3's tonal elevation system entirely.

---

## Dark Mode

**Current state:** hardcoded `.light()` at feature boundaries.

`ColorIsExpensiveTheme` has **complete dark scheme support** — `darkScheme()`, `darkMediumContrastScheme()`, `darkHighContrastScheme()` are all implemented (`color_is_expensive_theme.dart:L178-329`). Dark surface at `#1B1B1B`, dark primary at `#D4D4D6`.

**The gap:** Feature screens call `.light()` directly, ignoring the system brightness. When the user toggles dark mode at the app level, the result is dark chrome (from legacy theme) with light design system content — a visual inconsistency.

**Ideal single-root approach:**
1. Move `ColorIsExpensiveTheme` to `MaterialApp` root as both `theme` and `darkTheme`.
2. Use `themeMode: ThemeMode.system` (or user preference).
3. Register all `ThemeExtension`s (including brightness-aware `AppSemanticColors`) in both light and dark `ThemeData`.
4. Remove per-feature `Theme()` wrappers — they become unnecessary.

This leverages Flutter's built-in brightness switching. Every widget sees the correct theme via `Theme.of(context)`.

---

## Contrast Levels

Three `ColorScheme` variants per brightness, providing a progressive accessibility cascade:

| Level | Method | Tertiary Behavior | Purpose |
|-------|--------|-------------------|---------|
| **Standard** | `lightScheme()` / `darkScheme()` | Ghost — barely Lc 60, container ~invisible | Design ideal. Ghost enforces philosophy. |
| **Medium** | `lightMediumContrastScheme()` / `darkMediumContrastScheme()` | Partially visible — above Lc 60 | Moderate accessibility support. |
| **High** | `lightHighContrastScheme()` / `darkHighContrastScheme()` | Fully visible — normal M3 contrast | Full accessibility. Ghost effect disappears. |

Each level is a complete, manually specified `ColorScheme` — not a runtime adjustment. The `ThemeData` builders (`light()`, `lightMediumContrast()`, `lightHighContrast()`, etc.) at `color_is_expensive_theme.dart:L428-433` select the appropriate scheme.

`AppSemanticColors` also provides contrast variants: `light()`, `dark()`, `mediumContrast()`, `highContrast()`.

---

## Known Architecture Issues

### 1. Dual Theme (Legacy + Design System)

Two theme systems coexist:
- **Legacy** `MaterialTheme` (`lib/core/config/theme.dart`): chromatic blue primary (`#2633C5`), applied at app root.
- **Design system** `ColorIsExpensiveTheme` (`lib/design_system/theme/`): achromatic, applied locally via `Theme()` at feature boundaries.

**Risks:**
- Any widget calling `Theme.of(context).extension<AppSpacing>()!` outside a `Theme()` wrapper **throws a null assertion error** — extensions are not registered at the app root.
- Design system widgets used in non-wrapped screens render against the legacy blue theme.
- A 5-step migration path exists (add extensions to root -> migrate screens -> swap root -> remove wrappers -> delete legacy).

### 2. Local Theme() Injection Risks

The per-feature `Theme()` wrapper pattern creates fragility:
- Every new feature screen must remember to wrap with the design system theme.
- `Builder` is required to ensure children see the new theme context.
- `.light()` is hardcoded, blocking dark mode (see Dark Mode section).

### 3. Extension Null-Crash Prevention

Until migration to single root, any widget outside the design system boundary that accesses a `ThemeExtension` will crash. **Interim fix:** register `DesignSystemTheme.standardExtensions()` at the app root in `MaterialTheme`. This is additive and prevents null crashes without changing visuals.

### 4. surfaceTint Disabled Globally

`surfaceTintColor: Colors.transparent` on all surface-bearing components kills M3's tonal elevation system. With an achromatic primary, tint would produce a near-imperceptible grey-on-grey shift (~1-2% lightness). Disabling it is intentional — borders replace elevation as the separation mechanism. If a chromatic primary were ever adopted, surface tint should be re-evaluated.
