# Design System Decisions

Decisions captured during widget creation sessions, organized by topic.

Source: [`DESIGN_SYSTEM.md`](../DESIGN_SYSTEM.md) Decisions Log

---

## Architecture Decisions

### M3 Components Preferred (2026-02-24)

Shifted from primitives-only to M3-first approach. Use native Material 3
components for accessibility and consistency; build from primitives only when
M3 doesn't cover the need.

### Selective M3 Adoption (2026-02-24)

5 of 9 widgets reimplemented standard M3 patterns incompletely (missing ripple,
focus, keyboard, semantics). Switched to hybrid: M3 for standard interactions,
primitives for custom visuals (ChallengeCard, ScoreHeader, etc.).

### Dark Mode Gap (2026-02-27)

Complete dark schemes exist (`darkScheme()`, `darkMediumContrastScheme()`,
`darkHighContrastScheme()`) but feature screens hardcode `.light()`, ignoring
system brightness. Fix: move `ColorIsExpensiveTheme` to `MaterialApp` root with
`themeMode: ThemeMode.system` and remove per-feature wrappers.

**Status: Resolved.** Dark theme is wired at the `MaterialApp` root via
`theme:` / `darkTheme:` / `themeMode:`. No per-feature `.light()` overrides remain.

### Dual Theme Coexistence (2026-02-27)

Legacy `MaterialTheme` (chromatic blue `#2633C5`) lives at app root; design
system `ColorIsExpensiveTheme` (achromatic) is injected at feature boundaries
via `Theme()`. Widgets calling `Theme.of(context).extension<T>()!` outside a
wrapper crash. A 5-step migration path exists to consolidate to a single root.

**Status: Resolved (2026-03-02).** `ColorIsExpensiveTheme` is the sole theme at
the `MaterialApp` root. Legacy `MaterialTheme` deleted. Only `LegacyColors`
constants in `lib/core/config/legacy_colors.dart` remain for unmigrated screens.

---

## Color Decisions

### Achromatic Secondary & Tertiary (2026-02-23)

Secondary uses neutral-variant palette, tertiary uses pure neutral. All
chromatic color lives exclusively in `AppSemanticColors` — M3 structural roles
render grey.

### Ghost Tertiary (2026-02-23)

Tertiary pushed to near-invisibility (barely clears APCA Lc 60). Medium
contrast partially compensates; high contrast fully restores. Makes
`colorScheme.tertiary*` a trap role forcing use of `AppSemanticColors`.

### Surface Shifted to T96 for Grey Scaffold (2026-02-23)

Light `surface` moved from T99 near-white to `#F5F5F5` (T96) so
`scaffoldBackgroundColor` produces the grey background from Figma. Cards use
`surfaceContainerLowest` for white fills. Dark mode unchanged.

---

## Widget Implementation Decisions

### ChallengeCard Title Weight (2026-02-23)

Closest Material style to Figma's 16px/medium is `titleMedium` (16px/w500).
Kept as-is — no hard overrides. A different weight scale means refactoring the
entire `TextTheme`.

### ChallengeCard State Demotion (2026-02-23)

Replaced blanket `Opacity` with color-based demotion. `Opacity` reduces text
contrast below accessible thresholds. Use `onSurfaceVariant` for muted text and
`surfaceContainerLow` for tinted background instead.

### ChallengeCard Animation Loop Seam (2026-02-23)

Removed `CurvedAnimation(Curves.easeInOut)` from the looping border animation.
`easeInOut` stalls at both endpoints when repeating. Linear rotation is
seamless; for looping animations, use linear or C1-continuous curves.

### ScoreHeader Score Monospace (2026-02-23)

`displaySmall.copyWith(fontFamily: 'IBMPlexMono')` — functional override for
tabular number alignment. IBM Plex Mono is bundled in the app.

### ScoreHeader Countdown Bold (2026-02-23)

`labelSmall.copyWith(fontWeight: FontWeight.w700)` for countdown time value.
Deliberate deviation — weight contrast separates actionable data from the
"ENDS IN" label.

### Display Mono Unification (2026-03-03)

All display-class hero text (wallet balance, node status, permissions summary,
KPI percentages) uses IBM Plex Mono via `.copyWith(fontFamily: 'IBMPlexMono')`.
The `ScoreHeader` widget already applied this pattern; this decision extends it
to all primary KPI / status headlines across the app. Gives the app a consistent
technical/engineering identity. Affected screens: wallet, node status, quick
settings panel, slot production stats, produced blocks.

All five hero locations are unified to `displaySmall` (36px) — previously they
used four different M3 styles. `displaySmall` was already the most common choice
(wallet, produced blocks, ScoreHeader) and provides the right visual weight for
a primary KPI without dominating the screen.

See [TYPOGRAPHY.md](TYPOGRAPHY.md) for the full rule and table.

---

## Layout Decisions

### Screen Margin = space16 (2026-03-02)

16dp horizontal margin matches the M3 compact layout standard. Already in use
across DS screens. Codified as the canonical value.

### Section Gap = space24 (2026-03-02)

24dp between major content sections follows M3 macro spacing guidance for
compact devices. Distinguishes section breaks from card-to-card gaps (space16).

### Card Gap = space16 (2026-03-02)

16dp between same-type cards within a group. Tighter than section gaps to
maintain visual grouping.

### SliverPadding Preferred (2026-03-02)

Flutter docs recommend `SliverPadding` over wrapping `SliverToBoxAdapter`
children in `Padding`. `SliverPadding` participates in the sliver protocol
directly, avoiding unnecessary layout passes.

### Column/Row spacing Parameter Preferred (2026-03-02)

`Column(spacing: spacing.space16, ...)` replaces interleaved `SizedBox` widgets.
Available since Flutter 3.27; the project targets 3.35+. Reduces widget tree
depth and keeps spacing declarative.

### No Inter-Item Dividers by Default (2026-03-03)

Standard-density ListTile lists do not use dividers between items. The ListTile's
own M3 default spacing (16h contentPadding, minVerticalPadding: 8) provides
sufficient visual separation, especially inside Cards where the border groups items.

Dividers are appropriate only between semantically different content sections
within the same surface (e.g., address section above a transaction list).

### ListTile: M3 Layout Properties Are Interdependent (2026-03-03)

We tried overriding `visualDensity`, `minVerticalPadding`, `minTileHeight`, and
`titleAlignment` to get compact centered tiles. Each override fixed one symptom
but created another (misaligned icons, tiles crammed together). The M3 baseline
algorithm (magic numbers 32.0, 52.0, 72.0) assumes standard density and default
padding. Solution: only customize visual properties (text styles, colors, shape,
horizontal padding) in `ListTileThemeData`. Enforced by
`avoid_listtile_layout_overrides` lint.

---

## Compilation & Platform Decisions

### Widgetbook FFI Compilation Failure (2026-02-20)

Widgetbook failed on web: `AppAppBar` -> `NodeStatusIcon` ->
`nodeStatusProvider` -> Rust FFI. Adopted presentation-only rule: design system
widgets take data as props, never fetch state.
