# ParallaxSurfaceLayout — Genesis

## What

A layout widget that places a fixed header behind a scrolling surface container. The header translates upward at 40% of scroll speed (parallax), while the surface's top corners animate from rounded to flat. Supports multiple pinned header slivers, sliver-based surface content, NestedScrollView for tabbed content, header opacity fade, edge fade decorations, header overlays, and a shared `ValueNotifier<double>` that broadcasts scroll fraction (0–1) so external delegates can drive coordinated animations.

## Layer Architecture

```
Stack
├── Layer 1: Header (parallax)
│   ValueListenableBuilder reads scroll fraction →
│   Transform.translate shifts header at kParallaxRatio
│   Optional Opacity wrap when headerFadesOnScroll = true
│
├── Layer 2: Scroll view (dispatched by content param)
│   ├── CustomScrollView path (surfaceSlivers / surfaceBody):
│   │   ├── [...pinnedHeaderSlivers]  (multiple pinned bars)
│   │   ├── SliverToBoxAdapter         (transparent spacer = headerHeight)
│   │   └── surfaceSlivers path:
│   │       │   _SliverDecoratedBox    (animated corner decoration via RenderProxySliver)
│   │       │   └── SliverMainAxisGroup
│   │       │       ├── ...surfaceSlivers
│   │       │       └── SliverFillRemaining (background fill)
│   │       └── OR deprecated surfaceBody path:
│   │           └── SliverLayoutBuilder → SliverToBoxAdapter(ConstrainedBox → Container)
│   │
│   └── NestedScrollView path (nestedBody):
│       ├── headerSliverBuilder:
│       │   ├── [...pinnedHeaderSlivers]
│       │   ├── auto safe-area sliver (if applicable)
│       │   ├── SliverToBoxAdapter (transparent spacer = headerHeight)
│       │   └── [...surfacePinnedSlivers] (e.g. SurfaceTabBarDelegate)
│       └── body: ColoredBox(surfaceContainerLowest) → nestedBody
│
├── Layer 3: Header overlay (optional, headerOverlay)
│   Parallaxes and fades identically to Layer 1
│   HitTestBehavior.deferToChild — scroll gestures pass through
│   Only explicit GestureDetectors consume taps
│
└── Layer 4: Edge fade (optional, showEdgeFade)
    IgnorePointer → LinearGradient overlay at surface junction
    Opacity driven by scroll fraction — fades in as surface scrolls up
```

## Content Params (exactly one required)

| Param | Scroll view | Use case |
|-------|-------------|----------|
| `surfaceSlivers` | CustomScrollView | Most screens — lazy sliver content |
| `nestedBody` | NestedScrollView | Tabbed screens (TabBarView) |
| `surfaceBody` (deprecated) | CustomScrollView | Legacy box-based content |

## Scroll-Fraction Wiring

A single `ValueNotifier<double>` is the coordination bus:

1. `_onScroll` computes `pixels / headerHeight`, clamped to 0–1, and writes it.
2. The header's `ValueListenableBuilder` reads it for parallax offset (and optional opacity).
3. The surface's `ValueListenableBuilder` reads it for corner radius interpolation.
4. The edge fade's `ValueListenableBuilder` reads it for gradient opacity.
5. External consumers (e.g. `WalletScreen` delegates) receive the same notifier via `scrollFractionNotifier`.

When `scrollFractionNotifier` is null, an internal notifier is created and disposed automatically.

## RefreshIndicator Dispatch

When `onRefresh` is set:
- **Standard**: `RefreshIndicator` wrapping the scroll view.
- **No-spinner** (when `onRefreshStatusChange` is also set): `RefreshIndicator.noSpinner` with `onStatusChange` callback. Used by Challenges for custom pull-to-refresh scale animation on the ScoreHeader.

Both variants support `refreshNotificationPredicate` for custom scroll depth filtering (needed by NestedScrollView screens).

## _SliverDecoratedBox

Private render object (`RenderProxySliver`) that paints a `BoxDecoration` behind its sliver child. Used in the `surfaceSlivers` path to paint the surface background with animated corner radius. `ValueListenableBuilder` rebuilds with a new decoration each frame; `updateRenderObject` updates the `BoxPainter` efficiently.

## Debug Assertion (surfaceBody)

`_debugCheckUnboundedFlexChild` walks the deprecated `surfaceBody` widget tree looking for `Expanded`/`Flexible` in a vertical `Flex`. This combination crashes because `SliverToBoxAdapter → ConstrainedBox` provides unbounded maxHeight. The assertion fires in debug mode only, guiding migration to `surfaceSlivers`.

## Deprecation Strategy

Old singular params forward to new plural params internally:
- `pinnedHeaderSliver` → `pinnedHeaderSlivers`
- `pinnedHeaderHeight` → `pinnedHeadersHeight`
- `surfaceBody` → use `surfaceSlivers` instead

Assertions prevent mixing old and new params simultaneously.

## Reference Integration

All four main tab screens use PSL:
- **Wallet**: `surfaceSlivers` + `pinnedHeaderSlivers` (AddressBarDelegate)
- **DApps**: `surfaceSlivers` (auto safe-area)
- **Node Status**: `surfaceSlivers` (auto safe-area)
- **Challenges**: `nestedBody` + `pinnedHeaderSlivers` (ChipBarDelegate) + `surfacePinnedSlivers` (SurfaceTabBarDelegate) + `headerOverlay` (CTA button) + `onRefreshStatusChange` (pull feedback)

## Composition

**Use when:** A screen needs the "white sheet over grey scaffold" pattern with a parallax header. This is the primary scroll container for tab screens and detail screens.

**Parent containers:**
- Direct child of `Scaffold` body (primary use)
- Never nested inside another scroll container

**Pair with:**
- `ScoreHeader` in `header` slot (challenges, leaderboard)
- `TopAppBar` as a `pinnedHeaderSliver` for detail screens
- Custom `SliverPersistentHeaderDelegate` as `pinnedHeaderSlivers` (Wallet address bar, chip bars)
- `Tabs` / `TabBar` in `surfacePinnedSlivers` for tabbed content (`nestedBody` mode)
- Any slivers in `surfaceSlivers` — `SliverList`, `SliverToBoxAdapter`, `SliverPadding`

**Anti-patterns:**
- Don't use both `surfaceBody` (deprecated) and `surfaceSlivers` — use `surfaceSlivers` only
- Don't add top padding to the first surfaceSliver — PSL injects `kSurfaceTopInset` (8px) automatically
- Don't wrap `CustomScrollView` around PSL — it IS the scroll container
- Don't add `SafeArea` when PSL's `safeAreaOverlay` is true (default) — it handles status bar automatically

**Screen example:** `lib/features/wallet/screens/wallet_screen.dart` — PSL with `pinnedHeaderSlivers` (AddressBarDelegate) + `surfaceSlivers`; `lib/features/challenges/screens/challenges_screen.dart` — PSL with `nestedBody` for tabbed challenges
