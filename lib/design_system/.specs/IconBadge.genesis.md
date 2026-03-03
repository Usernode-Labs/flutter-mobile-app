# IconBadge — Genesis

## Figma Reference

Node `3621:15254` shows a List Item where the leading icon uses a 3-layer model:

```
Icon 48 (48×48)       ← outer container / touch target (transparent)
  Base (40×40)        ← colored surface (#FFDDBF in Figma)
    Icon 24 (24×24)   ← glyph centered
```

The existing `IconBadge` used a 2-layer model — the 48px container IS the colored
surface. The Figma intent separates layout allocation (48px) from visual surface
(40px), creating 4px breathing room on each side.

## Decision: `surfaceSize` Parameter

**Chosen:** Optional `double? surfaceSize` parameter.

**Alternatives considered:**

1. **Boolean `insetSurface`** — simpler API but hard-codes the relationship
   between container and surface size. Doesn't support arbitrary combinations
   (e.g., 56px container with 40px surface).

2. **Factory constructors** (`IconBadge.inset(...)`) — creates API surface area
   that's hard to evolve. A single constructor with an optional param is simpler.

3. **Separate widget** (`InsetIconBadge`) — violates DRY; the only difference is
   one extra `SizedBox` + `Center` wrapper.

**Rationale:** `surfaceSize` is the most flexible and composable option. It maps
directly to the Figma layer model, uses existing tokens (`iconContainerSmall`),
and preserves full backward compatibility — all existing callsites omit
`surfaceSize` and render identically.

## Default Flip: 3-Layer as Standard

After reviewing all 36+ callsites and the Figma design intent (node `3621:15254`),
the default was changed from 2-layer to 3-layer. `surfaceSize` now resolves to
`AppSizing.iconContainerSmall` (40px) when null, so every default-using callsite
automatically renders the inset surface without code changes. To get the old flush
look, pass `surfaceSize: sizing.iconContainerRegular`.

## Backward Compatibility

- Constructor signature unchanged — `surfaceSize` is still `double?`
- Visual change: default-using callsites now render 3-layer (matches Figma intent)
- No new required parameters

## Token Alignment

All three layers map to existing `AppSizing` tokens — no new tokens needed:

| Layer     | Token                  | Value |
|-----------|------------------------|-------|
| Container | `iconContainerRegular` | 48px  |
| Surface   | `iconContainerSmall`   | 40px  |
| Icon      | `iconRegular`          | 24px  |

## Border Radius

`borderRadius` applies to the colored surface in both modes. In 3-layer mode,
the outer `SizedBox` has no decoration — it's purely a layout allocation box.

## Precedent

`TopAppBar.spec.yaml:37-39` documents the same 3-layer pattern for icon buttons:

```yaml
touch_target: iconContainerRegular  # 48px
visible_size: iconContainerSmall    # 40px
icon_size: iconRegular              # 24px
```
