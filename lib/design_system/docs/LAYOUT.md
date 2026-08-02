# Base Layout System

Mobile-only layout targeting the compact window class (<600dp). All spacing derives from `AppSpacing` tokens on an 8pt grid — no new tokens needed. M3 distinguishes two levels: **micro** spacing (inside components) and **macro** spacing (between sections). Content width is fluid (full-width minus margins); no max-width constraint on mobile.

## Screen Anatomy

The native app is chromeless: `/home` renders the SV webview full-bleed (see `SvShellScreen`) and the old `HomeScreen` `IndexedStack` + BottomNav tab shell has been retired. Every native screen is now pushed via `context.push()` and uses the detail-screen shape below (e.g. Diagnostics, zk-identity detail).

```
Detail Screen (Diagnostics, ZkIdentityDetail)
┌──────────────────────────┐
│ TopAppBar (sliver,pinned)│
│  handles SafeArea        │
├──────────────────────────┤
│                          │
│ ← space16 → content   ← │
│                          │
│ ┌────────────────────┐   │
│ │ Card / Section     │   │
│ └────────────────────┘   │
│     ↕ space24 (section)  │
│ ┌────────────────────┐   │
│ │ Card / Section     │   │
│ └────────────────────┘   │
│     ↕ space32 (bottom)   │
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
| Bottom scroll padding | `space32` | 32dp | Last sliver — breathing room above the screen edge |

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

| Screen | Pattern | Pinned | Safe-area | Notes |
|--------|---------|--------|-----------|-------|
| Detail screens (Diagnostics, zk-identity detail) | `CustomScrollView` + `TopAppBar` | SliverAppBar | AppBar handles it | Standard detail pattern |
| Full-screen flows (zk-identity flow) | `ZkIdentityFlowPage` scaffold | None | Explicit `SafeArea` | Owns its own chrome |

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

Rejected for now. The current scroll stack uses Flutter SDK slivers, which
already cover pinned bars, grouped surfaces, and fills. Reconsider
`sliver_tools` only when an approved pattern needs behavior the SDK cannot
express cleanly.

## SafeArea Rules

| Screen type | SafeArea handling |
|-------------|-------------------|
| Detail screen with TopAppBar | Automatic — `SliverAppBar` handles top insets |
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

## Progressive Extensions (deferred)

- Grid layouts (2-column cards)
- Bottom sheet internal layout rules
- Full-bleed sections (edge-to-edge images, dividers)
- Responsive breakpoints (only if tablet support is added)
- Canonical layouts (list-detail, supporting pane — single-pane on mobile for now)

See also: [SCREEN_PATTERNS.md](SCREEN_PATTERNS.md) — full screen building playbook with templates and checklists.

---

Cross-references: [`app_spacing.dart`](../tokens/app_spacing.dart), [`app_sizing.dart`](../tokens/app_sizing.dart) (touch targets), [`SURFACES.md`](SURFACES.md), [`COLOR.md`](COLOR.md), [`CONSTRAINTS.md`](CONSTRAINTS.md)
