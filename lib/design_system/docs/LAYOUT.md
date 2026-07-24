# Base Layout System

Mobile-only layout targeting the compact window class (<600dp). All spacing derives from `AppSpacing` tokens on an 8pt grid — no new tokens needed. M3 distinguishes two levels: **micro** spacing (inside components) and **macro** spacing (between sections). Content width is fluid (full-width minus margins); no max-width constraint on mobile.

## Screen Anatomy

The native app is chromeless: `/home` renders the SV webview full-bleed (see `SvShellScreen`) and the old `HomeScreen` `IndexedStack` + BottomNav tab shell has been retired. Every native screen is now pushed via `context.push()`. The "tab screen" shape below is kept only as a spacing reference — screens like Node Status and Settings still use it as root scaffolds, just without a BottomNav underneath.

```
Tab Screen (Challenges, Wallet, Node)    Detail Screen (Leaderboard, ChallengeDetail)
┌──────────────────────────┐             ┌──────────────────────────┐
│ StatusBar (system)       │             │ TopAppBar (sliver,pinned)│
├──────────────────────────┤             │  handles SafeArea        │
│                          │             ├──────────────────────────┤
│ ← space16 →  content  ← │             │                          │
│                          │             │ ← space16 → content   ← │
│ ┌────────────────────┐   │             │                          │
│ │ Card / Section     │   │             │ ┌────────────────────┐   │
│ └────────────────────┘   │             │ │ Card / Section     │   │
│     ↕ space16            │             │ └────────────────────┘   │
│ ┌────────────────────┐   │             │     ↕ space24 (section)  │
│ │ Card / Section     │   │             │ ┌────────────────────┐   │
│ └────────────────────┘   │             │ │ Card / Section     │   │
│                          │             │ └────────────────────┘   │
│                          │             │     ↕ space32 (bottom)   │
├──────────────────────────┤             └──────────────────────────┘
│ BottomNav (from shell)   │
└──────────────────────────┘
```

## Spacing Roles

### Macro Spacing (between containers / sections)

| Role | Token | Value | Usage |
|------|-------|-------|-------|
| Screen margin (horizontal) | `space16` | 16dp | `EdgeInsets.symmetric(horizontal: spacing.space16)` |
| Section gap (distinct content groups) | `space24` | 24dp | Major logical breaks between sections |
| Card gap (same-type cards in a list) | `space16` | 16dp | Between cards of the same group |
| List item gap | `space12` | 12dp | `ListView.separated` or Column `spacing` |
| Bottom scroll padding | `space32` | 32dp | Last sliver — breathing room above BottomNav or screen edge |
| PSL surface body inset | `space24` | 24dp | Horizontal inset for non-ListTile content inside PSL `surfaceSlivers` |

### Micro Spacing (inside components)

| Role | Token | Value | Usage |
|------|-------|-------|-------|
| Card internal padding | `space16` | 16dp | `EdgeInsets.all(spacing.space16)` |
| Internal element gap | `space8` | 8dp | Between label and value within a card |
| Tight gap | `space4` | 4dp | Between heading and its body text |

## Keylines — Consistent Vertical Alignment

M2 defined explicit keylines (16dp margin, 72dp text keyline). M3 achieves the same alignment through component-level spacing defaults. We formalize three keylines:

```
Screen edge
│
├── K₀ (16dp) ── Card edges, chips, standalone widgets
│
│   Card edge
│   │
│   ├── K₁ (+16dp = 32dp from screen) ── Section titles, subheaders
│   │
│   └── K₂ (+72dp = 88dp from screen) ── Text after leading elements
│       ╭────────────────────╮
│       │ 16dp  40dp  16dp   │
│       │ pad   lead  gap    │
│       ╰────────────────────╯
```

| Keyline | From screen edge | From card edge | What aligns here |
|---------|-----------------|----------------|------------------|
| **K₀** | 16dp | — | Card edges, chips, top-level widgets |
| **K₁** | 32dp | 16dp | Section titles, subheaders inside cards |
| **K₂** | 88dp | 72dp | Text in ListTile / ExpansionTile with leading element |

**K₂ math**: `contentPadding.start` (16dp) + `minLeadingWidth` (40dp) + `horizontalTitleGap` (16dp) = 72dp from card edge. With 16dp screen margin → 88dp from screen.

**Rules:**
1. Screen margin (`SliverPadding horizontal: space16`) → K₀ at 16dp
2. Card padding (`AppCard.regular` / `contentPadding`) → K₁ at 32dp
3. ListTile/ExpansionTile with leading → K₂ at 88dp
4. **Never add manual Padding around ListTile/ExpansionTile** — it shifts K₂
5. Section titles inside list-bearing cards: explicit `Padding(horizontal: space16)` → K₁

**Keyline audit**: trace the padding chain from screen edge to text:
```
screen margin + card padding + widget padding + leading width + gap = offset
```

## Scroll Pattern Decision Tree

```
1. Pinned tabs with independently scrollable tab content?
   → NestedScrollView

2. TopAppBar (SliverAppBar) or multiple distinct sliver types?
   → CustomScrollView + SliverToBoxAdapter
   → Use SliverPadding for horizontal margins (not Padding inside child)

3. Simple list of similar items?
   → ListView.separated (with space12 separator)

4. Default (simple vertical stack)?
   → ListView or Column in SingleChildScrollView
```

**SliverPadding over Padding.** In `CustomScrollView`, wrap slivers in `SliverPadding` for screen margins instead of putting `Padding` inside each `SliverToBoxAdapter` child. `SliverPadding` is optimized for the sliver protocol and avoids unnecessary layout passes.

**Column/Row `spacing` parameter.** Use `Column(spacing: spacing.space16, ...)` instead of interleaving `SizedBox` widgets. Available since Flutter 3.27; the project targets Flutter 3.35+.

### Current Scroll Usage

| Screen | Pattern | Pinned | Safe-area | Surface inset | Notes |
|--------|---------|--------|-----------|---------------|-------|
| Wallet | `ParallaxSurfaceLayout` | AddressBarDelegate | Delegate handles it | `space24` | Single pinned bar |
| DApps | `ParallaxSurfaceLayout` | None | Auto pinned sliver | `space24` | `safeAreaOverlay` default |
| Node Status | `ParallaxSurfaceLayout` | None | Auto pinned sliver | `space24` | `safeAreaOverlay` default |
| Challenges | `ParallaxSurfaceLayout` nested body | ChipBar + TabBar | Delegate handles it | `space16` | `nestedBody` + `surfacePinnedSlivers` |
| Detail screens | `CustomScrollView` + `TopAppBar` | SliverAppBar | AppBar handles it | n/a | Different pattern |

### Scroll Design Principles

- Slivers for content, boxes for decoration. Use `SliverList` for anything potentially long.
- Pick one coordination bus per scroll view (`ValueNotifier`, `ScrollController.addListener`, or stream), not several.
- Declare pinning with `SliverAppBar(pinned: true)`, `SliverPersistentHeader`, or `surfacePinnedSlivers`; avoid ad hoc lerp math in screens.
- Edge fades should be cheap decoration (`Stack` + `Align` + `LinearGradient`) unless interaction requires more.
- Expose a `ScrollController` when scroll-to-top, keyboard navigation, or programmatic scrolling is expected.

### Open Gaps

| Gap | Status | Decision |
|-----|--------|----------|
| Snap-to-position physics | Open | Do not introduce a generic snap system until a real screen proves the need. Prefer native scroll behavior. |
| Scroll-driven item animations | Open | Keep per-screen and lightweight. New animation patterns need motion/a11y review and `MediaQuery.disableAnimations` handling. |

### Package Decision: `sliver_tools`

Rejected for now. The current scroll stack uses Flutter SDK slivers plus
`ParallaxSurfaceLayout`, which already covers pinned bars, grouped surfaces,
fills, and nested bodies. Reconsider `sliver_tools` only when an approved
pattern needs behavior the SDK cannot express cleanly.

## SafeArea Rules

| Screen type | SafeArea handling |
|-------------|-------------------|
| Detail screen with TopAppBar | Automatic — `SliverAppBar` handles top insets |
| Tab screen in IndexedStack | Wrap body in `SafeArea` — shell provides BottomNav |
| Full-screen (onboarding) | Explicit `SafeArea` around content |

## Rules

**Do:**
- Use `spacing.space16` for screen-edge horizontal margins
- Use `SliverPadding` for margins in `CustomScrollView`
- Use Column/Row `spacing:` parameter instead of `SizedBox` gaps
- Use `space24` between major content sections, `space16` between cards
- Place `TopAppBar` as first sliver in detail screens

**Don't:**
- Hardcode `const EdgeInsets.all(16)` — use token
- Use off-grid values (`20`, `10`, `14`)
- Wrap `SliverToBoxAdapter` children in `Padding` for screen margins (use `SliverPadding`)
- Add `SafeArea` when `TopAppBar` already handles insets
- Use `SingleChildScrollView` wrapping a `Column` when slivers are more appropriate

## Content Sheet Anatomy

The "white sheet over grey scaffold" pattern is implemented by [`ParallaxSurfaceLayout`](../src/parallax_surface_layout.dart): a fixed parallax header behind a scrolling surface container with animated corner radius.

### Layer Architecture

```
Stack (alignment: topCenter)
│
├── Layer 1 — Parallax header (fixed)
│   Padding(top: pinnedHeadersHeight + _autoSliverExtent)
│   └── SizedOverflowBox(height: headerHeight)  ← allows parallax overflow
│       └── Center(child: header)
│   Translates upward at 40% of scroll speed (kParallaxRatio).
│   Optional opacity fade (headerFadesOnScroll).
│
├── Layer 2 — CustomScrollView (scrollable)
│   ├── [...pinnedHeaderSlivers]    ← pinned bars (multiple supported)
│   ├── OR auto SafeAreaPinnedDelegate (safeAreaOverlay && no pinned headers)
│   │   └── extent = safeTop + kPinnedBarPadding (with title) or safeTop only (no title)
│   ├── SliverToBoxAdapter          ← transparent spacer (height: headerHeight)
│   └── surfaceSlivers path:
│       │   _SliverDecoratedBox(animated corners)
│       │   └── SliverMainAxisGroup
│       │       ├── ...surfaceSlivers
│       │       └── SliverFillRemaining (background fill)
│       └── OR deprecated surfaceBody path:
│           └── SliverToBoxAdapter(ConstrainedBox → Container → surfaceBody)
│
├── Layer 3 — Header overlay (optional, headerOverlay)
│   Padding(top: pinnedHeadersHeight + _autoSliverExtent)
│   └── SizedBox(height: headerHeight)  ← tight constraints, no overflow
│       └── headerOverlay widget
│   Parallaxes and fades with header. Interactive (taps land naturally).
│
└── Layer 4 — Edge fade overlay (optional, showEdgeFade)
    └── IgnorePointer → gradient that fades in with scroll
```

### API Quick-Reference

| Param | Purpose |
|-------|---------|
| `header` | Widget centered in the fixed parallax area |
| `surfaceSlivers` | Slivers inside the decorated surface (lazy-friendly) |
| `headerHeight` | Height of the transparent spacer / parallax zone |
| `pinnedHeaderSlivers` | Pinned slivers before the spacer (multiple) |
| `pinnedHeadersHeight` | Combined height offset for pinned slivers |
| `onRefresh` | Pull-to-refresh (wraps in `RefreshIndicator`) |
| `controller` | Optional `ScrollController` for programmatic scroll |
| `scrollFractionNotifier` | External notifier for delegate-driven animations |
| `headerFadesOnScroll` | Fade header opacity as user scrolls |
| `showEdgeFade` | Gradient overlay at surface junction |
| `safeAreaOverlay` | Auto status-bar overlay when no pinned headers (default `true`) |
| `kPinnedBarPadding` | 48px (8+32+8) — padding pinned bars add beyond safeTop; auto-sliver includes this for cross-screen alignment |
| `nestedBody` | Body for NestedScrollView (TabBarView etc.) |
| `surfacePinnedSlivers` | Slivers pinned at surface junction (nestedBody only) |
| `surfacePinnedHeight` | Combined height of surfacePinnedSlivers |
| `onRefreshStatusChange` | Custom refresh status callback (uses `.noSpinner`) |
| `refreshNotificationPredicate` | Custom scroll notification predicate |
| `headerOverlay` | Interactive widget above scroll surface, parallaxes with header |
| `surfaceFillsViewport` | (deprecated path only) Stretch surface for centering |
| ~~`surfaceBody`~~ | Deprecated — use `surfaceSlivers` |
| ~~`pinnedHeaderSliver`~~ | Deprecated — use `pinnedHeaderSlivers` |
| ~~`pinnedHeaderHeight`~~ | Deprecated — use `pinnedHeadersHeight` |

### Safe Area Strategies

`ParallaxSurfaceLayout` handles the status-bar safe-area automatically via
its `safeAreaOverlay` parameter (default `true`). When no `pinnedHeaderSlivers`
are provided, an internal pinned `SafeAreaPinnedDelegate` sliver is injected
inside the `CustomScrollView`, lerping from `surface` → `surfaceContainerLowest`.

The delegate height depends on the `title` parameter:
- **With `title`**: `safeTop + kPinnedBarPadding` (48 px) — provides a content
  slot for the title text, matching the structural offset of screens with pinned bars.
- **Without `title`**: `safeTop` only — minimal safe-area coverage with no
  empty gap below the status bar.

Screens that provide their own `pinnedHeaderSlivers` (e.g. Wallet) skip the
auto-sliver because their delegates already include safe-area handling.

| Pattern | pinnedHeaderSlivers | title | Example |
|---------|---------------------|-------|---------|
| Pinned bar + safe area | `SliverPersistentHeader` delegates | N/A (auto-skipped) | Wallet |
| Auto sliver with title | `null` | `'Node Status'` | Node Status |
| Auto sliver minimal | `null` | `null` | Challenges |
| No safe-area handling | `null` + `safeAreaOverlay: false` | N/A | Widgetbook |

### Surface Body Decoration Rules

- Content inherits the white surface background — remove explicit `surfaceContainerLowest` from containers that were previously standalone cards.
- Cards on white surface need `outlineVariant` border (see [SURFACES.md](SURFACES.md) white-on-white exception).
- Use `space24` gaps between major sections, not container-based visual grouping.

### PSL Surface Body Inset

Non-ListTile content inside a PSL `surfaceSlivers` body uses `space24` horizontal inset from the white surface edge. This aligns section titles, banners, and cards consistently across all PSL screens (Wallet, DApps, Node Status).

**Surface top inset** — PSL injects `kSurfaceTopInset` (8px) before the first surfaceSliver. Screens must NOT add their own top padding to the first sliver. Vertical gaps between slivers remain the screen's responsibility.

### Content Slot System

48px is the natural base height for surface content rows — M3 `IconButton` (48dp), `buttonHeightRegular` (48dp), `iconContainerRegular` (48dp), and `kTabBarHeight` (48dp) all converge on this value. When every first-surface-widget delivers a 48px slot, the title text centers at the same Y (~22px from surface) across all PSL screens.

**Composable layouts expecting slots** — containers whose spacing assumes 48px-height children:

| Layout | Path | Status |
|--------|------|--------|
| PSL `surfaceSlivers` | `parallax_surface_layout.dart` | Adopted — `kSurfaceTopInset=8` tuned for 48px first slot |
| PSL `nestedBody` + `surfacePinnedSlivers` | `parallax_surface_layout.dart` | Prior art — `_kTopInset=8` + `kTabBarHeight=48` |

**Atomic widgets delivering 48px slots** — building blocks that fill a single slot:

| Widget | Mechanism | Slot | Status |
|--------|-----------|------|--------|
| M3 TabBar (Challenges) | `kTabBarHeight = 48.0` | 48px natural | Prior art |
| Title+action row (dApps `_SortBar`) | `SizedBox(height: sizing.iconContainerRegular)` + `Row` | 48px explicit | Adopted |
| Section title row (Wallet) | `SizedBox(height: sizing.iconContainerRegular)` + `Align(centerStart)` | 48px explicit | Adopted |
| Title+value row (Node Status) | `SizedBox(height: sizing.iconContainerRegular)` + `Row` | 48px explicit | Adopted |
| `ListTile` | M3 default 56–72dp | Multi-slot | Compatible |

Multi-slot widgets snap to the 8pt grid — taller is fine, no explicit constraints needed.

**Exemptions:**
- **ListTile / ExpansionTile** — sit edge-to-edge within the surface; they own their `contentPadding` (16dp from theme).
- **Challenges** (`nestedBody` / TabBarView) — uses `space16`; different layout path with pinned tab bar.

```dart
// Section title inside PSL surface — use SliverPadding for horizontal inset
SliverPadding(
  padding: EdgeInsets.symmetric(horizontal: spacing.space24),
  sliver: SliverToBoxAdapter(
    child: Text('Section Title', style: textTheme.titleMedium),
  ),
)
```

### NestedScrollView Support

Screens that need `NestedScrollView` with independently-scrollable `TabBarView` content use the `nestedBody` parameter. PSL internally creates a `NestedScrollView` with the standard parallax header structure. Use `surfacePinnedSlivers` for elements (like a tab bar) that pin at the surface junction.

See [ParallaxSurfaceLayout genesis doc](../.specs/ParallaxSurfaceLayout.genesis.md) for full architecture.

## Progressive Extensions (deferred)

- Grid layouts (2-column cards)
- Bottom sheet internal layout rules
- Full-bleed sections (edge-to-edge images, dividers)
- Responsive breakpoints (only if tablet support is added)
- Canonical layouts (list-detail, supporting pane — single-pane on mobile for now)

See also: [SCREEN_PATTERNS.md](SCREEN_PATTERNS.md) — full screen building playbook with templates and checklists.

---

Cross-references: [`app_spacing.dart`](../tokens/app_spacing.dart), [`app_sizing.dart`](../tokens/app_sizing.dart) (touch targets), [`SURFACES.md`](SURFACES.md), [`COLOR.md`](COLOR.md), [`CONSTRAINTS.md`](CONSTRAINTS.md)
