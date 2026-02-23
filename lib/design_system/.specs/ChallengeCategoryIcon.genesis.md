# ChallengeCategoryIcon — Genesis Document

> Companion widget to ChallengeCard. Renders theme-aware SVG category icons.

## Inspiration

- **Source**: Figma node `3012:2775` — three abstract geometric category icons (technical, community, flash)
- **Reference**: See `ChallengeCard.reference.png` (icons visible in card headers)

## Design Decisions

### SVG Export from Figma

The official Figma MCP exports individual vector layers as PNGs (known limitation). SVGs were manually exported from Figma's export panel. Community SVG required svgo optimization (103 KB to 6 KB).

### Embedded SVG Strings (No Asset Files)

All three SVGs are under 7 KB — small enough to embed as Dart string constants. This avoids asset pipeline overhead and allows template-based color injection at runtime.

### 3-Layer Structure

All icons share a consistent visual language — only the geometry differs:

| Layer | Purpose | Opacity |
|-------|---------|---------|
| Inner shape | Category fill | 20% |
| Outer shape | Category fill | 10% |
| Stroke outline | `onSurface` color | 100% (flash: 80% dashed) |

### Theme-Aware Color Injection

SVG templates use `{{C}}` (category color) and `{{S}}` (stroke/onSurface) placeholders. Colors resolved at build time from `AppSemanticColors` and `colorScheme.onSurface`, ensuring automatic adaptation across all 6 theme variants.

### Token Mapping

| Figma hex | Semantic token | Purpose |
|-----------|---------------|---------|
| `#0070FC` | `semantic.technical.color` | Technical icon fill |
| `#008C21` | `semantic.community.color` | Community icon fill |
| `#FFC900` | `semantic.flash.color` | Flash icon fill |
| (dark lines) | `colorScheme.onSurface` | Stroke outlines |

The widget uses runtime tokens, not Figma hex values, so icons adapt to every theme contrast level.
