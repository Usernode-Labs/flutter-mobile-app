# Scroll Patterns

Scroll architecture for the "white sheet over grey scaffold" pattern. See [`ParallaxSurfaceLayout`](../src/parallax_surface_layout.dart) source and [genesis doc](../.specs/ParallaxSurfaceLayout.genesis.md).

Full ecosystem research (7 apps, 46+ packages): [`.archive/scroll-patterns-research.md`](../.archive/scroll-patterns-research.md)

## Current Usage

| Screen | Pattern | Pinned | Safe-area | Surface Inset | Notes |
|--------|---------|--------|-----------|---------------|-------|
| Wallet | `ParallaxSurfaceLayout` | AddressBarDelegate (1) | Delegate handles it | `space24` | Single pinned bar |
| DApps | `ParallaxSurfaceLayout` | None | Auto pinned sliver | `space24` | `safeAreaOverlay` (default) |
| Node Status | `ParallaxSurfaceLayout` | None | Auto pinned sliver | `space24` | `safeAreaOverlay` (default) |
| Challenges | `ParallaxSurfaceLayout` (nestedBody) | ChipBar + TabBar (2) | Delegate handles it | `space16` | `nestedBody` + `surfacePinnedSlivers` |
| Detail screens | `CustomScrollView` + `TopAppBar` | SliverAppBar (1) | AppBar handles it | n/a | Different pattern |

### Surface Body Inset Convention

All PSL screens using `surfaceSlivers` apply `space24` horizontal inset for non-ListTile content (titles, banners, cards). ListTile/ExpansionTile widgets are exempt — they sit edge-to-edge. Challenges uses `space16` via its `nestedBody`/TabBarView path. See [LAYOUT.md § PSL Surface Body Inset](LAYOUT.md#psl-surface-body-inset).

## Design Principles

Distilled from Wonderous, Natrium, PiliPala, GSYGitHub, Immich, Medito, Spotube.

1. **Slivers for content, boxes for decoration.** `SliverList` for anything potentially long. `SliverToBoxAdapter` only for fixed-height elements.
2. **One coordination bus.** Pick one mechanism (`ValueNotifier`, `ScrollController.addListener`, or `StreamController.broadcast`) per scroll view. Never mix.
3. **Declare pinning, don't implement it.** `SliverAppBar(pinned: true)` or `SliverPinnedHeader` over manual delegates with lerp math.
4. **Edge fades are the cheapest scroll affordance.** `Stack` + `Align` + `LinearGradient` — no listeners needed (Natrium pattern).
5. **Layer header effects independently.** Translation, opacity, scale should each be driven by the same notifier with different formulas — composable, not monolithic.
6. **Expose the controller.** 6/7 production apps expose `ScrollController` for scroll-to-top, keyboard nav, programmatic scroll.

## Open Gaps

Gaps 1–5 from the original audit are resolved (`surfaceSlivers`, `pinnedHeaderSlivers`, `controller`, `headerFadesOnScroll`, `showEdgeFade`). Safe-area status-bar overlay is also resolved (`safeAreaOverlay`). Remaining:

| # | Gap | Impact | Effort |
|---|-----|--------|--------|
| 6 | No snap-to-position physics | Low-Med | Medium |
| 7 | No scroll-driven item animations | Low | Medium |

## Package Decision: sliver_tools

~644k downloads. Was considered for Gaps 1+2. **Not adopted** — gaps resolved in-house using `SliverMainAxisGroup` (Flutter 3.35+) and a private `_SliverDecoratedBox`. No external dependency needed.

---

Cross-references: [`LAYOUT.md`](LAYOUT.md) § Content Sheet Anatomy, [`SURFACES.md`](SURFACES.md), [`parallax_surface_layout.dart`](../src/parallax_surface_layout.dart)
