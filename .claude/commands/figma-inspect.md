Extract a Figma design into a structured spec file for the widget builder pipeline.

## Input

A Figma URL: $ARGUMENTS

## Steps

### 1. Parse the URL

Extract `fileKey` and `nodeId` from the Figma URL.

- Format: `https://figma.com/design/:fileKey/:fileName?node-id=:int1-:int2`
- `fileKey` = the path segment after `/design/`
- `nodeId` = query param `node-id` with `-` replaced by `:` (e.g., `1-2` becomes `1:2`)

### 2. Call Figma MCP tools

Run these in parallel:

1. **`get_design_context`** with `fileKey` and `nodeId` — returns layout structure, styles, and code hints
2. **`get_screenshot`** with `fileKey` and `nodeId` — visual reference
3. **`get_variable_defs`** with `fileKey` and `nodeId` — design token variables

After retrieving the screenshot, save it to
`lib/design_system/.specs/<WidgetName>.reference.png`.
This is the visual inspiration for the widget — not a spec to match,
but context for understanding the design intent.

### 3. Map Figma values to project tokens

Read `lib/core/config/theme.dart` and `lib/design_system/DESIGN_SYSTEM.md` for the token vocabulary.

Apply these snapping rules:

**Spacing** (snap to nearest `AppSpacing` value):
| Figma px | Token |
|----------|-------|
| 0-6 | `space4` (4) |
| 7-10 | `space8` (8) |
| 11-14 | `space12` (12) |
| 15-20 | `space16` (16) |
| 21-28 | `space24` (24) |
| 29-40 | `space32` (32) |
| 41+ | `space48` (48) |

**Border Radius** (snap to nearest `AppRadii` value):
| Figma px | Token |
|----------|-------|
| 0-10 | `small` (8) |
| 11-14 | `medium` (12) |
| 15-18 | `large` (16) |
| 19-22 | `largeIncreased` (20) |
| 23-100 | `xLarge` (24) |
| 100+ | `full` (999) |

**Colors** — match against `ColorScheme` properties from `theme.dart`:
- Primary colors: `primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`
- Secondary: `secondary`, `onSecondary`, `secondaryContainer`, `onSecondaryContainer`
- Tertiary: `tertiary`, `onTertiary`, `tertiaryContainer`, `onTertiaryContainer`
- Error: `error`, `onError`, `errorContainer`, `onErrorContainer`
- Surface: `surface`, `onSurface`, `onSurfaceVariant`
- Surface variants: `surfaceBright`, `surfaceDim`, `surfaceContainerLowest`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest`
- Outline: `outline`, `outlineVariant`
- Inverse: `inverseSurface`, `inversePrimary`

Match by closest hex value. If no colorScheme property matches within a reasonable tolerance, note it in `mapping_notes`.

**Typography** — match against `textTheme` properties by size + weight:
- `displayLarge`, `displayMedium`, `displaySmall`
- `headlineLarge`, `headlineMedium`, `headlineSmall`
- `titleLarge`, `titleMedium`, `titleSmall`
- `bodyLarge`, `bodyMedium`, `bodySmall`
- `labelLarge`, `labelMedium`, `labelSmall`

**Elevation** (snap to `AppElevation`):
| Figma shadow | Token |
|-------------|-------|
| none | `none` (0) |
| blur 1-2 | `low` (1) |
| blur 3-4 | `medium` (2) |
| blur 5-6 | `high` (4) |
| blur 7+ | `max` (8) |

**Opacity** (snap to `AppOpacity`):
| Figma % | Token |
|---------|-------|
| 5-10% | `subtle` (0.08) |
| 11-16% | `medium` (0.12) |
| 17-25% | `strong` (0.20) |
| 26-35% | `disabled` (0.30) |
| 36-50% | `secondary` (0.40) |

**Sizing** (snap to `AppSizing`):
- Containers: `iconContainerSmall` (40), `iconContainerRegular` (48), `iconContainerLarge` (56), `iconContainerXLarge` (64)
- Icons: `iconSmall` (20), `iconRegular` (24), `iconLarge` (28), `iconXLarge` (32)
- Buttons: `buttonHeightSmall` (40), `buttonHeightRegular` (48), `buttonHeightLarge` (56)

### 4. Derive widget name and constructor params

- Widget name: PascalCase from the Figma layer/component name
- Scan for dynamic content (text that varies per instance) and map to constructor parameters
- Use `{{paramName}}` placeholders in the spec for dynamic content
- Callbacks: detect interactive areas (buttons, tap targets) and add `VoidCallback?` or typed callbacks

### 5. Write the spec YAML

Output to `lib/design_system/.specs/<WidgetName>.spec.yaml` using this format:

```yaml
meta:
  figma_url: "<original URL>"
  widget_name: "<PascalCase name>"
  description: "<one-line description from Figma context>"
  generated_by: claude
  date: "<today's date>"
  reference_screenshot: "<WidgetName>.reference.png"

layout:
  type: <column|row|stack|wrap|single>
  spacing: <token name>
  padding: { all: <token> } # or { horizontal: <token>, vertical: <token> } or { top: ..., left: ..., etc. }
  cross_axis_alignment: <start|center|end|stretch>
  main_axis_alignment: <start|center|end|spaceBetween|spaceAround|spaceEvenly>
  decoration:
    color: <colorScheme property>
    border_radius: <AppRadii token>
    elevation: <AppElevation token>
    border:
      color: <colorScheme property>
      width: <number>
  children:
    - type: <text|icon|image|container|row|column|stack|spacer|divider|custom>
      # type-specific properties...

params:
  - { name: <paramName>, type: <DartType>, required: <true|false> }

mapping_notes:
  - { figma_value: "<raw value>", mapped_to: "<token>", confidence: <exact|nearest> }
```

### 6. Flag non-exact mappings

After writing the spec, output a summary:
- Total mappings made
- Exact matches vs nearest snaps
- Any values that couldn't be mapped (flag for human review)

If there are `nearest` confidence mappings, mention them explicitly so the human can verify.

### 7. Write the initial genesis document

Output to `lib/design_system/.specs/<WidgetName>.genesis.md`. This captures early decisions made *during* inspection — before the user even reviews the spec. Later pipeline steps append to it.

Review everything you did in steps 2-6 and extract decisions worth recording:

**What counts as a decision:**
- **Non-obvious token snaps** — any `nearest` confidence mapping where you picked one token over a plausible alternative (e.g., `surfaceContainerLowest` vs `surfaceBright` when both are `#FFFFFF`)
- **Figma ambiguity resolved** — when the Figma node was a list/group and you had to identify the repeating unit, or when layer names were generic and you inferred the widget boundary
- **Structural interpretation** — choosing column vs stack, deciding what's a variant vs a separate widget, identifying which content is dynamic vs static
- **Missing tokens flagged** — Figma values that don't snap cleanly and might need a new token (like `20px` radius before `largeIncreased` existed)
- **Params derived** — why certain Figma text was made a param vs hardcoded, callbacks inferred from tap targets

**What is NOT a decision** (skip these):
- Exact 1:1 token matches (Figma 16px padding -> `space16` — obvious, no decision)
- Standard text style mappings that match by size+weight
- Boilerplate structure (meta fields, file paths)

Use this format:

```markdown
# <WidgetName> — Genesis Document

> Tracks every design decision from Figma inspection through implementation.
> New sections are appended as the widget evolves.

## Phase 1: Figma Inspection (<today's date>)

### Source
- **Figma node**: `<nodeId>` — <brief description of what the node contains>
- <any notes about the node scope — e.g., "this is a list, the widget is the repeating item">

### Decisions During Inspection

#### <Decision title>
<What was decided and why. Keep it concise — 1-3 sentences.>

#### <Next decision>
...

### Non-Exact Mappings
| Element | Figma value | Mapped to | Why this choice |
|---------|------------|-----------|-----------------|
| ... | ... | ... | ... |
```

Only include sections that have content. If the inspection was clean (all exact matches, obvious structure), a short genesis with just the source section is fine — don't pad it with non-decisions.

### 8. Confirm output

Print the paths to all generated files and a brief summary of the widget structure.
Then list the decisions captured in the genesis doc so the user can verify them.
