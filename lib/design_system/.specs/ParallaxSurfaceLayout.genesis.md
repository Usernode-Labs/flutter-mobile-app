# ParallaxSurfaceLayout — Genesis

## What

A layout widget that places a fixed header behind a scrolling surface container. The header translates upward at 40% of scroll speed (parallax), while the surface's top corners animate from rounded to flat. Supports an optional pinned bar sliver and a shared `ValueNotifier<double>` that broadcasts scroll fraction (0–1) so external delegates can drive coordinated animations.

## Layer Architecture

```
Stack
├── Layer 1: Header (parallax)
│   ValueListenableBuilder reads scroll fraction →
│   Transform.translate shifts header at kParallaxRatio
│
└── Layer 2: CustomScrollView
    ├── [pinnedHeaderSliver]  (optional — e.g. sticky address bar)
    ├── SliverToBoxAdapter    (transparent spacer = headerHeight)
    └── SliverToBoxAdapter    (decorated surface with animated corners)
```

The scroll view sits on top of the header in the Stack. The transparent spacer lets the header show through; as the user scrolls past it, the surface takes over the full viewport.

## Scroll-Fraction Wiring

A single `ValueNotifier<double>` is the coordination bus:

1. `_onScroll` computes `pixels / headerHeight`, clamped to 0–1, and writes it.
2. The header's `ValueListenableBuilder` reads it for parallax offset.
3. The surface's `ValueListenableBuilder` reads it for corner radius interpolation.
4. External consumers (e.g. `WalletScreen` delegates in `wallet_delegates.dart`) receive the same notifier via `scrollFractionNotifier` and drive their own animations.

When `scrollFractionNotifier` is null, an internal notifier is created and disposed automatically.

## Constraint Chain (`surfaceFillsViewport`)

When `surfaceFillsViewport: true`, the surface must fill the viewport (ensuring scroll distance) while centering the body in only the initially-visible portion:

```
SliverLayoutBuilder  (reads viewportMainAxisExtent)
  └── ConstrainedBox (minHeight: viewportHeight — stretches surface)
        └── Container  (decoration: animated corners)
              └── Align (loosens minHeight — lets child be smaller)
                    └── SizedBox (height: visibleSurfaceHeight)
                          └── surfaceBody
```

The `Align` widget is key: without it, `ConstrainedBox`'s `minHeight` propagates as a tight constraint, so the body would stretch to the full viewport instead of centering in the visible area.

## Reference Integration

`WalletScreen` (`lib/features/wallet/screens/wallet_screen.dart`) is the primary consumer, with scroll-fraction delegates extracted to `wallet_delegates.dart`.
