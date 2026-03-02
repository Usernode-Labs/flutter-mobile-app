# M3 Theme Audit & Alignment Document

> Archived from Intent workspace note `9f5862d8-656c-42aa-87c2-2bdc32f36181` (Feb 2026).
> Full unabridged research content.

---

This audit documents every design decision in the current theme system, its rationale, how it aligns or conflicts with Material 3 recommendations, and actionable recommendations for resolution.

**Files analyzed:**
- `lib/design_system/theme/color_is_expensive_theme.dart` — achromatic design system theme
- `lib/design_system/tokens/app_semantic_colors.dart` — chromatic color isolation
- `lib/design_system/tokens/` — all 7 token extensions
- `lib/design_system/theme/design_system_theme.dart` — extension wiring
- `lib/design_system/DESIGN_SYSTEM.md` — design philosophy
- `lib/core/config/theme.dart` — legacy MaterialTheme
- `lib/core/config/design_tokens.dart` — legacy constant tokens
- `lib/main.dart` — app-level theme application
- `lib/features/challenges/screens/challenges_screen.dart` — local theme injection

---

## A. Color Scheme Decisions

### A1. Primary: Achromatic Near-Black

| Aspect | Detail |
|--------|--------|
| **Implemented** | `#252627` (light), `#D4D4D6` (dark) — near-black ink with zero chroma. `color_is_expensive_theme.dart:24` |
| **Designer's reasoning** | "The attention locker." Maximum contrast CTAs. Same darkness as body text, distinguished by shape (button vs paragraph). Color is scarce = color is valuable. All chromatic emphasis deferred to `AppSemanticColors`. |
| **M3 recommended** | Primary is the **brand seed color**, typically chromatic (e.g., deep purple `#6750A4`). M3 generates a tonal palette (primary0–primary100) from this seed. Primary fills buttons, FABs, active indicators. It is the primary brand signal. |
| **Conflict** | **HIGH.** M3's entire tonal system assumes a chromatic primary. Flutter's `ColorScheme.fromSeed()` cannot produce an achromatic primary. Components like `FilledButton`, `FloatingActionButton`, `Switch`, `Checkbox`, `Radio`, `ProgressIndicator`, and `NavigationBar` indicator all render in `primary` — these will be near-black/grey instead of branded. Users scanning the UI get no brand color signal from standard M3 components. |
| **Recommendation** | Keep the achromatic primary for the design system boundary where "color is expensive" applies. For the app-wide theme, set primary to a low-chroma brand color (e.g., a desaturated blue-grey `#4A5568`) so standard M3 components outside the design system still carry brand identity. Within the design system, widgets already use `AppSemanticColors` for chromatic emphasis, so the achromatic primary is consistent with philosophy. Document in DESIGN_SYSTEM.md that `primary` is not brand-colored by design. |

### A2. Secondary: Achromatic Neutral-Variant

| Aspect | Detail |
|--------|--------|
| **Implemented** | `#5C5E64` (light), `#C8CAD0` (dark) — cool-leaning grey from neutral-variant palette. `color_is_expensive_theme.dart:29` |
| **Designer's reasoning** | Structural emphasis without hue. Secondary actions get grey, not color. Consistent with "color is expensive" — secondary is utility, not attention. |
| **M3 recommended** | Secondary is typically a complementary or analogous chromatic color to primary. Used for less prominent components (filter chips, tonal buttons). M3 expects secondary to be visually distinct from primary. |
| **Conflict** | **MEDIUM.** The achromatic secondary is close in lightness to `onSurfaceVariant` (`#44474D`), risking visual confusion between secondary interactive elements and passive text. However, since the design system pushes all meaningful color to `AppSemanticColors`, this intentional "flatness" is consistent. |
| **Recommendation** | Accept the achromatic secondary. Add a 1-line comment in `color_is_expensive_theme.dart:29` documenting that secondary is deliberately achromatic and should not be used for visual distinction — use `AppSemanticColors` instead. Verify that `FilledTonalButton` (which uses `secondaryContainer`) provides sufficient contrast against `surface` (currently `#E1E2E8` on `#F5F5F5` — ~ΔL 5, marginal). |

### A3. Tertiary: Ghost Role

| Aspect | Detail |
|--------|--------|
| **Implemented** | `#757575` (light), `#B8B8B8` (dark) — pure neutral grey. Container `#F5F5F5` nearly identical to `surface` `#F5F5F5`. `color_is_expensive_theme.dart:33–36` |
| **Designer's reasoning** | "Ghost role." Deliberately starved of contrast. Container is ~ΔY 6 from surface (nearly invisible). Tertiary is a "trap role" — technically accessible (APCA Lc ~60), practically invisible. Forces developers to `AppSemanticColors` for real emphasis. Medium/high contrast variants progressively restore visibility. |
| **M3 recommended** | Tertiary is a **third accent color** for contrast balance, often complementary to primary. M3 uses tertiary for extended color expression (e.g., tertiary containers for differentiated sections). |
| **Conflict** | **HIGH.** Any developer using `colorScheme.tertiary` or `tertiaryContainer` expecting a visible accent gets nothing. This is intentional but undocumented in code — only in DESIGN_SYSTEM.md. Third-party packages using M3 tertiary roles will render invisibly. |
| **Recommendation** | Keep the ghost tertiary — it's a core design philosophy enforcement mechanism. Add a `// GHOST: deliberately near-invisible. Use AppSemanticColors for emphasis.` comment at `color_is_expensive_theme.dart:33`. Add a Dart doc-comment on the class explaining that `tertiary*` roles are intentionally muted. This prevents accidental misuse by new developers or packages. |

### A4. Error: Chromatic Red

| Aspect | Detail |
|--------|--------|
| **Implemented** | `#BD0F19` (light), `#FFA28C` (dark). `color_is_expensive_theme.dart:37–40` |
| **M3 recommended** | Error seed `#B3261E`, generating error tonal palette. M3 standard light error is `#B3261E`. |
| **Conflict** | **LOW.** `#BD0F19` is a slightly more saturated red than M3's `#B3261E` but functionally equivalent. The error container `#FFBFA9` vs M3's `#F9DEDC` is warmer/more orange-tinted. |
| **Recommendation** | Accept as-is. The deviation is minor and the APCA contrast pipeline has verified these values. No action needed. |

### A5. Surface Hierarchy

| Aspect | Detail |
|--------|--------|
| **Implemented** | 5-level surface container gradient: `surfaceContainerLowest` `#FFFFFF` → `surfaceContainerHighest` `#E2E2E2`. Base `surface` at `#F5F5F5` (T96). `color_is_expensive_theme.dart:41,64–68` |
| **M3 recommended** | M3 also provides 5 surface container levels. Default `surface` is near-white (~T99, `#FEF7FF` with tint). M3's surface containers carry the primary tint color. |
| **Conflict** | **MEDIUM.** Surface is shifted 3 tonal steps darker than M3 default (T96 vs T99). M3's surfaces carry a primary-tinted overlay; this implementation is pure achromatic grey — no tint. `surfaceTintColor: Colors.transparent` is set everywhere, explicitly killing M3's tonal elevation system. |
| **Recommendation** | Accept the T96 surface for the grey-scaffold model — this is a deliberate design choice documented in DESIGN_SYSTEM.md. The transparent `surfaceTintColor` is necessary to maintain the achromatic philosophy. Document that dark mode should keep `surface` at `#1B1B1B` (confirmed at `color_is_expensive_theme.dart:198`). |

### A6. Outline and Structural Colors

| Aspect | Detail |
|--------|--------|
| **Implemented** | `outline`: `#74777E`, `outlineVariant`: `#C4C6CC`. `color_is_expensive_theme.dart:44–45` |
| **M3 recommended** | M3 `outline` (~`#79747E`) for important boundaries, `outlineVariant` (~`#CAC4D0`) for decorative boundaries. |
| **Conflict** | **LOW.** Values are nearly identical to M3 defaults. The cool-grey lean (from neutral-variant palette) vs M3's warm-grey is consistent with the achromatic philosophy. |
| **Recommendation** | No change needed. Values align well with M3 structural expectations. |

### A7. Inverse Colors

| Aspect | Detail |
|--------|--------|
| **Implemented** | `inverseSurface`: `#303030`, `inversePrimary`: `#C5C6C8`. `color_is_expensive_theme.dart:48–49` |
| **M3 recommended** | Inverse surface for snackbars/tooltips — dark on light theme, providing maximum contrast. |
| **Conflict** | **LOW.** Aligned with M3 intent. `inversePrimary` is achromatic (consistent with achromatic primary). |
| **Recommendation** | No change needed. |

### A8. APCA vs WCAG 2.x

| Aspect | Detail |
|--------|--------|
| **Implemented** | All color pairs verified against APCA (Accessible Perceptual Contrast Algorithm): body text Lc >= 90, accents Lc >= 60, borders Lc >= 30. Per DESIGN_SYSTEM.md:67. |
| **M3 recommended** | M3 references WCAG 2.x (4.5:1 AA for normal text, 3:1 AA for large text). M3 does not officially adopt APCA. |
| **Conflict** | **MEDIUM.** APCA is more perceptually accurate but not yet a WCAG standard (still draft in WCAG 3.0). Some APCA-passing combinations may fail WCAG 2.x AA ratios, and vice versa. Legal/compliance contexts may require WCAG 2.x conformance. |
| **Recommendation** | Dual-verify: Run all color pairs through both APCA Lc thresholds AND WCAG 2.x contrast ratios. Document any pairs where APCA passes but WCAG 2.x fails, and vice versa. For accessibility compliance claims, state "APCA-verified" rather than "WCAG AA compliant" until WCAG 3.0 finalizes. Add the medium/high contrast scheme variants as an accessibility fallback (already implemented). |

---

## B. Surface Architecture

### B1. Two-Tier Model vs M3 Five-Level Tonal Gradient

| Aspect | Detail |
|--------|--------|
| **Implemented** | Grey scaffold (`surface` `#F5F5F5`) + white content (`surfaceContainerLowest` `#FFFFFF`). Cards, nav bar, bottom sheet, dialog, drawer all use `surfaceContainerLowest`. Separation via `outlineVariant` borders, not elevation. `color_is_expensive_theme.dart:346–425` |
| **M3 recommended** | Components spread across 5 surface container levels for tonal hierarchy. Cards at `surfaceContainerLow`, nav bar at `surfaceContainer`, dialogs at `surfaceContainerHigh`. Elevation creates tonal shifts via `surfaceTint`. |
| **Conflict** | **HIGH.** The implementation collapses M3's 5 levels to 2. All content-level components land on `surfaceContainerLowest` (#FFFFFF). M3's subtle tonal differentiation between card, nav bar, and dialog is lost. A `NavigationBar` and a `Card` are visually identical (both white, both flat). |
| **Recommendation** | Accept the two-tier model as the design system's surface philosophy. It's well-documented in DESIGN_SYSTEM.md:150–190. To reduce risk: (1) add the "Decision Principle for New Components" from DESIGN_SYSTEM.md as a code comment in `color_is_expensive_theme.dart` near the component theme section, (2) keep the full 5-level surface container gradient in the ColorScheme (already done — `color_is_expensive_theme.dart:62–68`) so individual widgets can opt into tonal hierarchy if needed. |

### B2. `surfaceTintColor: Colors.transparent` Everywhere

| Aspect | Detail |
|--------|--------|
| **Implemented** | Set on AppBar (`:353`), NavigationBar (`:360`), BottomSheet (`:365`), Card (`:372`), Dialog (`:382`), Drawer (`:397`). |
| **M3 recommended** | `surfaceTintColor` defaults to `colorScheme.surfaceTint` (= `primary`). M3 uses surface tint to create tonal elevation — elevated surfaces get a primary-tinted overlay, visually lifting them. |
| **Conflict** | **HIGH.** Transparent tint kills M3's entire tonal elevation system. Elevated surfaces look identical to flat surfaces. This is intentional (achromatic philosophy) but means M3's `ElevationOverlay` system does nothing. |
| **Recommendation** | Keep `surfaceTintColor: Colors.transparent` — it's core to the achromatic philosophy. Add a block comment in `color_is_expensive_theme.dart:346` explaining: "Tonal elevation disabled. Hierarchy via grey/white layering + outlineVariant borders. See DESIGN_SYSTEM.md §Surface Architecture." |

### B3. `scrolledUnderElevation: 0` on AppBar

| Aspect | Detail |
|--------|--------|
| **Implemented** | `scrolledUnderElevation: 0` at `color_is_expensive_theme.dart:352` |
| **M3 recommended** | Default `scrolledUnderElevation: 3` — when content scrolls under the app bar, M3 applies a tonal shift to signal layering. |
| **Conflict** | **MEDIUM.** Without scroll tint, the AppBar and scrolled content merge visually. Users lose the cue that content is behind the bar. |
| **Recommendation** | Keep `scrolledUnderElevation: 0` to avoid tonal shifts on the grey scaffold. Instead, add a `Divider` or `outlineVariant` border at the bottom of AppBar when scrolled, as a non-tonal layering signal. This should be a separate implementation task, not done here. |

### B4. Card Border Instead of Elevation

| Aspect | Detail |
|--------|--------|
| **Implemented** | `CardThemeData` with `elevation: 0`, `surfaceTintColor: transparent`, and `outlineVariant` border. `color_is_expensive_theme.dart:369–377` |
| **M3 recommended** | Cards default to `surfaceContainerLow` with elevation 1, using tonal elevation to separate from background. Three card variants: elevated, filled, outlined. |
| **Conflict** | **LOW.** The implementation is equivalent to M3's **outlined card** variant (`OutlinedCard`), which uses `surface` background + `outlineVariant` border + elevation 0. This is a valid M3 card style. |
| **Recommendation** | Rename the mental model from "card with border" to "M3 Outlined Card" in documentation. This is already M3-compatible. No code change needed. |

---

## C. Component Theme Overrides

### C1. AppBarTheme

| Override | Value | M3 Default | Why | M3-Compatible? | Breakage Risk |
|----------|-------|-----------|-----|----------------|---------------|
| `backgroundColor` | `colorScheme.surface` | `colorScheme.surface` | Same as default | **Yes** | None |
| `foregroundColor` | `colorScheme.onSurface` | `colorScheme.onSurface` | Same as default | **Yes** | None |
| `elevation` | `0` | `0` | Same as default | **Yes** | None |
| `scrolledUnderElevation` | `0` | `3` | Kill scroll tint | **No** — removes scroll feedback | Low — cosmetic only |
| `surfaceTintColor` | `transparent` | `surfaceTint` | Kill tonal elevation | **No** — disables tonal system | Low — cosmetic, but if M3 changes default behavior, override keeps it stable |

**File ref:** `color_is_expensive_theme.dart:348–354`

### C2. NavigationBarThemeData

| Override | Value | M3 Default | Why | M3-Compatible? | Breakage Risk |
|----------|-------|-----------|-----|----------------|---------------|
| `height` | `80` | `80` | Documents intent | **Yes** | None |
| `backgroundColor` | `surfaceContainerLowest` | `surfaceContainer` | White nav on grey page | **No** — 2 levels lower | Low |
| `elevation` | `0` | `0` (M3 default with surface tint) | Flat | **Yes** | None |
| `surfaceTintColor` | `transparent` | `surfaceTint` | Kill tint | **No** | Low |

**File ref:** `color_is_expensive_theme.dart:356–361`
**Note:** No `indicatorColor` override — M3 default (`secondaryContainer`) applies. With achromatic secondary, the indicator will be grey `#E1E2E8`.

### C3. BottomSheetThemeData

| Override | Value | M3 Default | Why | M3-Compatible? | Breakage Risk |
|----------|-------|-----------|-----|----------------|---------------|
| `backgroundColor` | `surfaceContainerLowest` | `surfaceContainerLow` | White sheet | **No** — 1 level lower | Low |
| `surfaceTintColor` | `transparent` | `surfaceTint` | Kill tint | **No** | Low |
| `elevation` | `0` | `1` | Flat | **No** — removes shadow | Low |

**File ref:** `color_is_expensive_theme.dart:363–367`

### C4. CardThemeData

| Override | Value | M3 Default | Why | M3-Compatible? | Breakage Risk |
|----------|-------|-----------|-----|----------------|---------------|
| `color` | `surfaceContainerLowest` | `surfaceContainerLow` | White card | **Partial** — matches outlined card variant | Low |
| `elevation` | `0` | `1` | Flat | **Yes** for outlined card | None |
| `surfaceTintColor` | `transparent` | `surfaceTint` | Kill tint | **No** for elevated card | Low |
| `shape` | `RoundedRectangleBorder` r16 + `outlineVariant` border | `RoundedRectangleBorder` r12 | Border-separated | **Yes** for outlined card (M3 uses r12, this uses r16 — minor deviation) | Low |

**File ref:** `color_is_expensive_theme.dart:369–377`

### C5. DialogThemeData

| Override | Value | M3 Default | Why | M3-Compatible? | Breakage Risk |
|----------|-------|-----------|-----|----------------|---------------|
| `backgroundColor` | `surfaceContainerLowest` | `surfaceContainerHigh` | White dialog | **No** — 4 levels lower | Low |
| `elevation` | `0` | `6` | Flat (scrim provides separation) | **No** — removes depth cue | Medium — dialogs without shadow can feel "pasted on" |
| `surfaceTintColor` | `transparent` | `surfaceTint` | Kill tint | **No** | Low |
| `shape` | `RoundedRectangleBorder` r24 | `RoundedRectangleBorder` r28 | Slightly tighter corner | **No** — r24 vs r28 | Low |

**File ref:** `color_is_expensive_theme.dart:379–386`

### C6. DividerThemeData

| Override | Value | M3 Default | Why | M3-Compatible? | Breakage Risk |
|----------|-------|-----------|-----|----------------|---------------|
| `color` | `outlineVariant` | `outlineVariant` | Same | **Yes** | None |
| `thickness` | `1` | `1` | Same | **Yes** | None |
| `space` | `1` | `16` | Zero-padding divider | **No** — removes default padding | Low — affects layout |

**File ref:** `color_is_expensive_theme.dart:388–392`

### C7. DrawerThemeData

| Override | Value | M3 Default | Why | M3-Compatible? | Breakage Risk |
|----------|-------|-----------|-----|----------------|---------------|
| `backgroundColor` | `surfaceContainerLowest` | `surfaceContainerLow` | White panel | **No** — 1 level lower | Low |
| `surfaceTintColor` | `transparent` | `surfaceTint` | Kill tint | **No** | Low |
| `elevation` | `0` | `1` | Flat | **No** | Low |

**File ref:** `color_is_expensive_theme.dart:394–398`

### C8. SnackBarThemeData

| Override | Value | M3 Default | Why | M3-Compatible? | Breakage Risk |
|----------|-------|-----------|-----|----------------|---------------|
| `behavior` | `floating` | `fixed` | Material 3 recommends floating | **Yes** | None |
| `shape` | r12 | r4 | Rounder corners | **No** — minor visual deviation | Low |

**File ref:** `color_is_expensive_theme.dart:400–405`

### C9. ListTileThemeData

| Override | Value | M3 Default | Why | M3-Compatible? | Breakage Risk |
|----------|-------|-----------|-----|----------------|---------------|
| `contentPadding` | `horizontal: 16, vertical: 4` | `horizontal: 16, vertical: 0` | Extra vertical breathing room | **Partial** — horizontal matches | Low |
| `dense` | `true` | `false` | Compact layout | **No** — reduces height | Low |
| `visualDensity` | `compact` | `standard` | Even more compact | **No** — stacks with dense | Medium — double-compaction may make tap targets too small (<48dp) |
| `shape` | r12 | none | Rounded tiles | **No** — adds border radius | Low |
| `titleTextStyle` | `bodyMedium` + `onSurface` | `bodyLarge` + `onSurface` | Smaller title | **No** — one size smaller | Low |
| `subtitleTextStyle` | `bodySmall` + `onSurfaceVariant` | `bodyMedium` + `onSurfaceVariant` | Smaller subtitle | **No** — one size smaller | Low |

**File ref:** `color_is_expensive_theme.dart:407–425`
**Risk note:** `dense: true` + `visualDensity: compact` together can push ListTile height below M3's 48dp minimum touch target. Verify actual rendered height meets accessibility guidelines.

---

## D. Token System

### D1. ThemeExtension Approach vs M3 Built-in Tokens

| Aspect | Detail |
|--------|--------|
| **Implemented** | 7 custom `ThemeExtension` classes: `AppSpacing`, `AppRadii`, `AppElevation`, `AppOpacity`, `AppSizing`, `AppAnimation`, `AppSemanticColors`. Registered via `DesignSystemTheme.standardExtensions()` at `design_system_theme.dart:45–56`. Accessed via `Theme.of(context).extension<T>()!`. |
| **M3 built-in** | M3 defines spacing, shape, and elevation through `MaterialStateProperty`, `ShapeBorder`, and `ElevationOverlay`. Flutter doesn't yet expose M3's full design token system as ThemeExtensions. |
| **Conflict** | **LOW.** Flutter's M3 implementation doesn't provide a comprehensive token API. ThemeExtensions are the idiomatic Flutter approach for custom tokens. The pattern is future-compatible — when/if Flutter adds native M3 tokens, these extensions can delegate to them. |
| **Recommendation** | Keep the ThemeExtension approach. It's the correct Flutter pattern. No change needed. |

### D2. Token Value Alignment with M3

| Token | App Value | M3 Default | Alignment |
|-------|-----------|------------|-----------|
| **AppSpacing** `space4–space48` | 4, 8, 12, 16, 24, 32, 48 | M3 uses 4dp grid: 4, 8, 12, 16, 24, 32, 48 | **Exact match** |
| **AppRadii** `small–full` | 8, 12, 16, 20, 24, 999 | M3 shape: extra-small=4, small=8, medium=12, large=16, extra-large=28, full=∞ | **Close.** `largeIncreased` (20) and `xLarge` (24) don't map to M3's `extra-large` (28). |
| **AppElevation** `none–max` | 0, 1, 2, 4, 8 | M3 elevation: 0, 1, 3, 6, 8, 12 | **Divergent.** M3 uses 0/1/3/6/8/12; app uses 0/1/2/4/8. Missing levels 3 and 6. |
| **AppOpacity** | 0.08, 0.12, 0.20, 0.30, 0.40 | M3 state layers: hover=0.08, focus=0.10, pressed=0.10, dragged=0.16 | **Partial match.** `subtle` (0.08) matches hover. Others are custom. |
| **AppSizing** icons/buttons | 20, 24, 28, 32 / 40, 48, 56 | M3 icon: 24dp default. M3 touch target: 48dp minimum | **Aligned** on key values (24 icon, 48 touch target) |
| **AppAnimation** | 100, 150, 200, 300ms | M3 motion: short1=50ms, short2=100ms, medium1=250ms, medium2=300ms, long1=450ms | **Partial.** 100ms ≈ short2, 300ms ≈ medium2. 150ms and 200ms have no M3 equivalent. |

**File refs:** Token files in `lib/design_system/tokens/`
**Legacy mirror:** `lib/core/config/design_tokens.dart` has identical constants (not ThemeExtensions) — `kSpace4..kSpace48`, `kRadiusSmall..kRadiusFull`, `kElevationNone..kElevationMax` with exactly matching values.

### D3. AppSemanticColors as Chromatic Escape Hatch

| Aspect | Detail |
|--------|--------|
| **Implemented** | 4 semantic groups: `technical` (blue), `flash` (amber), `community` (green), `success` (green). Each has `color/onColor/colorContainer/onColorContainer` quad. Light/dark/mediumContrast/highContrast variants. `app_semantic_colors.dart:46–223` |
| **M3 equivalent** | M3's `ColorScheme.fromSeed()` generates `primary/secondary/tertiary` with tonal palettes. M3 also supports "custom colors" via `harmonize()` for brand-specific roles. |
| **Conflict** | **LOW.** `AppSemanticColors` is functionally equivalent to M3's "custom colors" or "extended colors" concept. The `SemanticColorGroup` mirrors M3's 4-role pattern (color/onColor/container/onContainer). |
| **Recommendation** | Keep as-is. This is well-designed and M3-aligned in structure. Consider adding a `harmonize()` pass using `MaterialColorUtilities` to ensure semantic colors harmonize with the primary palette's hue — though with an achromatic primary, harmonization is a no-op. No action needed now. |

---

## E. Dual Theme Architecture

### E1. Legacy vs Design System Theme

| Aspect | Detail |
|--------|--------|
| **Legacy theme** | `MaterialTheme` in `lib/core/config/theme.dart`. Chromatic blue primary (`#2633C5`), blue secondary (`#00B6F0`), green tertiary (`#4CAF50`). Applied at app root via `main.dart:236–237`. |
| **Design system theme** | `ColorIsExpensiveTheme` in `lib/design_system/theme/`. Achromatic primary (`#252627`), ghost tertiary (`#757575`). Applied locally at feature boundaries via `Theme()` widget. |
| **Application pattern** | App root: `MaterialTheme(textTheme).light()` at `main.dart:236`. Feature screen: `Theme(data: ColorIsExpensiveTheme(textTheme).light().copyWith(extensions: ...))` at `challenges_screen.dart:113–118`. |

### E2. Theme Injection Pattern

At `challenges_screen.dart:113–118`:
```dart
return Theme(
  data: ColorIsExpensiveTheme(textTheme).light().copyWith(
    extensions: DesignSystemTheme.standardExtensions(
      semanticColors: AppSemanticColors.light(),
    ),
  ),
  child: Builder(builder: (context) => _buildBody(context)),
);
```

**Analysis:**
- Creates a full `ThemeData` from `ColorIsExpensiveTheme`, then adds extensions via `copyWith`
- Uses `Builder` to ensure child widgets see the new theme via `Theme.of(context)`
- Hardcodes `.light()` — no dark mode support at the design system boundary

### E3. Theme Leak Risks

| Risk | Severity | Description |
|------|----------|-------------|
| **Downward leak** | LOW | Design system theme is scoped via `Theme()` widget. Children see it correctly. |
| **Upward leak** | NONE | `Theme()` widget doesn't affect ancestors. |
| **Sibling leak** | MEDIUM | If another feature screen doesn't wrap with `ColorIsExpensiveTheme`, its design system widgets will render against the legacy blue theme. Any design system widget used outside the `Theme()` boundary gets wrong colors. |
| **Extension absence** | HIGH | The legacy `MaterialTheme` at the app root has **no ThemeExtensions**. Any widget calling `Theme.of(context).extension<AppSpacing>()!` outside a design system boundary will throw a null assertion error. |

### E4. Dark Mode Gap

| Aspect | Detail |
|--------|--------|
| **App root** | `themeMode: themeMode` (from provider) — supports light/dark toggle. `main.dart:238` |
| **Design system boundary** | Always `.light()` — `challenges_screen.dart:114`. `ColorIsExpensiveTheme` has full dark scheme support (`darkScheme()`, `dark()`) but it's never called. |
| **Impact** | When user toggles dark mode, the app root switches to `MaterialTheme.dark()`. But the challenges screen stays light. Visual inconsistency: dark chrome + light content area. |
| **Recommendation** | Pass brightness-awareness into the design system theme injection. Change `challenges_screen.dart:114` from `ColorIsExpensiveTheme(textTheme).light()` to brightness-aware selection: `final brightness = MediaQuery.of(context).platformBrightness; final dsTheme = brightness == Brightness.dark ? ColorIsExpensiveTheme(textTheme).dark() : ColorIsExpensiveTheme(textTheme).light();` Similarly, switch `AppSemanticColors.light()` to `.dark()` based on brightness. This should be a separate implementation task. |

### E5. Migration Path

| Step | Action | Risk |
|------|--------|------|
| 1 | Add `ThemeExtensions` to app-root `MaterialTheme` | LOW — additive, no visual change |
| 2 | Add `AppSemanticColors` to app-root theme | LOW — additive |
| 3 | Migrate screens one-by-one from legacy to `ColorIsExpensiveTheme` | MEDIUM — each screen changes visually |
| 4 | Remove local `Theme()` wrappers once app-root uses `ColorIsExpensiveTheme` | LOW — simplification |
| 5 | Delete `MaterialTheme` class | LOW — cleanup |

---

## F. Recommendations Summary

### Risk-Ranked Decision Table

| # | Decision | Alignment Risk | Recommendation |
|---|----------|---------------|----------------|
| 1 | Achromatic primary `#252627` | **HIGH** | Keep for design system boundary. Add brand-tinted primary to app-root theme for non-design-system M3 components. Document in DESIGN_SYSTEM.md. |
| 2 | Ghost tertiary `#757575` | **HIGH** | Keep — core philosophy. Add `// GHOST` code comment at `color_is_expensive_theme.dart:33`. Add class-level doc-comment. |
| 3 | Two-tier surface (grey/white) | **HIGH** | Keep — well-documented. Add decision principle as code comment in theme file near component overrides. |
| 4 | `surfaceTintColor: transparent` everywhere | **HIGH** | Keep — required for achromatic philosophy. Add explanatory block comment at `color_is_expensive_theme.dart:346`. |
| 5 | No dark mode at design system boundary | **HIGH** | Change `challenges_screen.dart:114` to use brightness-aware theme selection. Create separate task. |
| 6 | Extension absence at app root | **HIGH** | Add `DesignSystemTheme.standardExtensions()` to app-root `MaterialTheme` in `lib/core/config/theme.dart:369`. Prevents null crashes for widgets used outside design system boundary. |
| 7 | `scrolledUnderElevation: 0` on AppBar | **MEDIUM** | Keep, but add scroll-state border as alternative feedback. Separate task. |
| 8 | Dialog elevation 0 + r24 | **MEDIUM** | Keep elevation 0 (scrim separation). Change r24 to r28 to match M3 dialog spec. |
| 9 | ListTile `dense + compact` | **MEDIUM** | Verify rendered height >= 48dp. If not, remove one of `dense`/`visualDensity: compact`. |
| 10 | APCA vs WCAG 2.x | **MEDIUM** | Dual-verify all pairs. Document as "APCA-verified" not "WCAG AA compliant". |
| 11 | Achromatic secondary `#5C5E64` | **MEDIUM** | Keep. Verify `FilledTonalButton` contrast on `surface`. Add code comment. |
| 12 | `surfaceContainerLowest` for BottomSheet, Drawer | **MEDIUM** | Keep — consistent with two-tier model. |
| 13 | AppElevation 0/1/2/4/8 vs M3 0/1/3/6/8/12 | **MEDIUM** | Add `level3: 3.0` and `level6: 6.0` to `AppElevation` to cover M3 elevation levels. Prevents mismatches when wrapping M3 components. |
| 14 | AppRadii `xLarge: 24` vs M3 `extra-large: 28` | **LOW** | Change `xLarge` from 24 to 28 to match M3 spec. Update dialog shape to use `radii.xLarge` (which would then be 28, matching M3's r28). |
| 15 | SnackBar r12 shape | **LOW** | Accept — minor visual preference. |
| 16 | DividerTheme `space: 1` | **LOW** | Keep — zero-padding divider is intentional for custom layouts. |
| 17 | Error color `#BD0F19` | **LOW** | Accept — functionally equivalent to M3 error. |
| 18 | Outline colors | **LOW** | No change — aligned with M3. |
| 19 | Token system (ThemeExtension) | **LOW** | No change — idiomatic Flutter pattern. |
| 20 | AppSemanticColors structure | **LOW** | No change — well-designed, M3-aligned structure. |

### Recommended Migration Order

**Phase 1 — Low-risk fixes (can be done immediately):**
1. Add `// GHOST` comments and class doc to `ColorIsExpensiveTheme`
2. Add `ThemeExtensions` to app-root `MaterialTheme` (prevents null crashes)
3. Change `AppRadii.xLarge` from 24 to 28
4. Add `level3` and `level6` to `AppElevation`

**Phase 2 — Medium-risk improvements (separate tasks):**
5. Fix dark mode at design system boundary (`challenges_screen.dart`)
6. Verify ListTile touch target height with `dense + compact`
7. Dual-verify APCA + WCAG 2.x for all color pairs
8. Change dialog shape r24 → r28

**Phase 3 — Architecture decisions (requires design discussion):**
9. Decide whether app-root theme migrates to `ColorIsExpensiveTheme`
10. Decide whether to add brand-tinted primary for non-design-system contexts
11. Add scroll-state feedback (border) for AppBar

---

## Appendix: Color Value Quick Reference

### Light Scheme Key Colors

| Role | Hex | Notes |
|------|-----|-------|
| `primary` | `#252627` | Near-black, achromatic |
| `onPrimary` | `#FFFFFF` | White on near-black |
| `secondary` | `#5C5E64` | Cool grey |
| `tertiary` | `#757575` | Ghost grey |
| `error` | `#BD0F19` | Signal red |
| `surface` | `#F5F5F5` | Grey scaffold (T96) |
| `surfaceContainerLowest` | `#FFFFFF` | White content |
| `onSurface` | `#1B1B1B` | Near-black text |
| `onSurfaceVariant` | `#44474D` | Secondary text |
| `outline` | `#74777E` | Important borders |
| `outlineVariant` | `#C4C6CC` | Decorative borders |

### Legacy Theme Key Colors (for comparison)

| Role | Hex | Notes |
|------|-----|-------|
| `primary` | `#2633C5` | Chromatic blue |
| `secondary` | `#00B6F0` | Chromatic cyan |
| `tertiary` | `#4CAF50` | Chromatic green |
| `surface` | `#F2F3F8` | Cool-tinted white |

### Semantic Colors (Light)

| Group | Color | Container |
|-------|-------|-----------|
| `technical` | `#0055D9` (blue) | `#D3D9FF` |
| `flash` | `#875300` (amber) | `#FFD87B` |
| `community` | `#146D32` (green) | `#B6F0BE` |
| `success` | `#1A6D23` (green) | `#BAF1B4` |
