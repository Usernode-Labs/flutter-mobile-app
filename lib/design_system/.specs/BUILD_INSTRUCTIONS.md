# Widget Build Instructions

These instructions are consumed by `usernode-ds-build-widget` during DS widget build and review work.

Read a `.spec.yaml` file from this directory and produce a complete design system widget. Use Dart MCP tools throughout — see "Dart MCP Tools" section below for prescribed usage.

## Design System Constraints

### Widget approach
Design system widgets are **slot widgets** — small, focused components (IconBadge, StatusBadge, ScoreHeader) that compose into M3 containers at the screen level. They do NOT wrap M3 container widgets.

Build DS widgets from Flutter core primitives:
- Layout: Container, Padding, Row, Column, Stack, ...
- Interaction: GestureDetector, InkWell
- Animation: AnimatedContainer, AnimatedOpacity, ...
- Painting: CustomPaint, DecoratedBox, ClipRRect, ...

### Presentation-only rule
Widgets are data-in, pixels-out:
- All state comes via constructor parameters (data + callbacks)
- No providers, no `ConsumerWidget`, no `ConsumerStatefulWidget`
- No services, no async loading, no state fetching
- No FRB-generated types in constructor params (they import native FFI)
- Feature screens in `lib/features/` handle state and pass data down

## Token-to-Code Reference

### Spacing (`AppSpacing`)
```dart
final spacing = Theme.of(context).extension<AppSpacing>()!;
// Available: spacing.space4, .space8, .space12, .space16, .space24, .space32, .space48
SizedBox(height: spacing.space16)           // vertical gap
Padding(padding: EdgeInsets.all(spacing.space16))  // uniform padding
EdgeInsets.symmetric(horizontal: spacing.space16, vertical: spacing.space8)
```

### Border Radius (`AppRadii`)
```dart
final radii = Theme.of(context).extension<AppRadii>()!;
// Available: radii.small (8), .medium (12), .large (16), .xLarge (24), .full (999)
// Convenience getters:
radii.borderRadiusSmall      // BorderRadius.all(Radius.circular(8))
radii.borderRadiusMedium     // BorderRadius.all(Radius.circular(12))
radii.borderRadiusLarge      // BorderRadius.all(Radius.circular(16))
radii.borderRadiusXLarge     // BorderRadius.all(Radius.circular(24))
radii.borderRadiusFull       // BorderRadius.all(Radius.circular(999))
radii.borderRadiusTopLarge   // top-only large
radii.borderRadiusTopXLarge  // top-only xLarge
// Or manual: BorderRadius.circular(radii.medium)
```

### Elevation (`AppElevation`)
```dart
final elevation = Theme.of(context).extension<AppElevation>()!;
// Available: elevation.none (0), .low (1), .medium (2), .high (4), .max (8)
// Use with BoxShadow in BoxDecoration:
BoxDecoration(
  boxShadow: elevation.low > 0
    ? [BoxShadow(
        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
        blurRadius: elevation.low * 2,
        offset: Offset(0, elevation.low),
      )]
    : null,
)
```

### Opacity (`AppOpacity`)
```dart
final opacity = Theme.of(context).extension<AppOpacity>()!;
// Available: opacity.subtle (0.08), .medium (0.12), .strong (0.20), .disabled (0.30), .secondary (0.40)
color.withValues(alpha: opacity.subtle)
Opacity(opacity: opacity.disabled, child: ...)
```

### Sizing (`AppSizing`)
```dart
final sizing = Theme.of(context).extension<AppSizing>()!;
// Containers: sizing.iconContainerSmall (40), .iconContainerRegular (48), .iconContainerLarge (56), .iconContainerXLarge (64)
// Icons: sizing.iconSmall (20), .iconRegular (24), .iconLarge (28), .iconXLarge (32)
// Buttons: sizing.buttonHeightSmall (40), .buttonHeightRegular (48), .buttonHeightLarge (56)
SizedBox(width: sizing.iconContainerRegular, height: sizing.iconContainerRegular)
Icon(Icons.star, size: sizing.iconRegular)
```

### Animation (`AppAnimation`)
```dart
final animation = Theme.of(context).extension<AppAnimation>()!;
// Available: animation.fast (100ms), .normal (150ms), .slow (200ms), .complex (300ms)
AnimatedContainer(duration: animation.normal, ...)
```

### Semantic Colors (`AppSemanticColors`)
```dart
final semantic = Theme.of(context).extension<AppSemanticColors>()!;
// Groups: semantic.technical, .flash, .community, .success
// Each group has: .color, .onColor, .colorContainer, .onColorContainer
// Standalone accent:
Container(color: semantic.technical.color)
// Tinted background with text:
Container(
  color: semantic.flash.colorContainer,
  child: Text('Flash', style: TextStyle(color: semantic.flash.onColorContainer)),
)
```
See DESIGN_SYSTEM.md "Color Philosophy" section for usage guidelines.

### Colors (`ColorScheme`)
```dart
final colors = Theme.of(context).colorScheme;
// Primary: colors.primary, .onPrimary, .primaryContainer, .onPrimaryContainer
// Secondary: colors.secondary, .onSecondary, .secondaryContainer, .onSecondaryContainer
// Tertiary: colors.tertiary, .onTertiary, .tertiaryContainer, .onTertiaryContainer
// Error: colors.error, .onError, .errorContainer, .onErrorContainer
// Surface: colors.surface, .onSurface, .onSurfaceVariant
// Surface variants: colors.surfaceBright, .surfaceDim, .surfaceContainerLowest, .surfaceContainerLow, .surfaceContainer, .surfaceContainerHigh, .surfaceContainerHighest
// Outline: colors.outline, .outlineVariant
// Inverse: colors.inverseSurface, .inversePrimary
```

### Typography (`TextTheme`)
```dart
final textTheme = Theme.of(context).textTheme;
// Display: textTheme.displayLarge, .displayMedium, .displaySmall
// Headline: textTheme.headlineLarge, .headlineMedium, .headlineSmall
// Title: textTheme.titleLarge, .titleMedium, .titleSmall
// Body: textTheme.bodyLarge, .bodyMedium, .bodySmall
// Label: textTheme.labelLarge, .labelMedium, .labelSmall
Text('Hello', style: textTheme.titleMedium)
Text('Hello', style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant))
```

## Layout Type Mapping

Map the `type` field in the spec to Flutter widgets:

| Spec type | Flutter widget |
|-----------|---------------|
| `column` | `Column` |
| `row` | `Row` |
| `stack` | `Stack` |
| `wrap` | `Wrap` |
| `single` | direct child (no wrapper) |
| `text` | `Text` |
| `icon` | `Icon` |
| `spacer` | `SizedBox` with spacing token |
| `divider` | `Container` with height 1 and outline color |
| `container` | `Container` or `DecoratedBox` |
| `image` | `placeholder` (add TODO comment for asset integration) |

## Reading the Spec

### `{{paramName}}` placeholders
Every `{{paramName}}` in the spec becomes a constructor parameter. The `params` section defines name, Dart type, and whether it's required.

### `decoration` block
Maps to `BoxDecoration`:
- `color` → `colorScheme.<property>`
- `border_radius` → `radii.<token>` or `radii.borderRadius<Token>`
- `elevation` → `BoxShadow` list (see elevation reference above)
- `border.color` → `colorScheme.<property>`
- `border.width` → literal (borders are structural, not tokenized)

### `padding` block
- `{ all: <token> }` → `EdgeInsets.all(spacing.<token>)`
- `{ horizontal: <h>, vertical: <v> }` → `EdgeInsets.symmetric(...)`
- `{ top: <t>, bottom: <b>, left: <l>, right: <r> }` → `EdgeInsets.only(...)`

## Required Output Files

For a widget named `FooBar`:

### 1. Widget: `lib/design_system/src/foo_bar.dart`
- Class `FooBar` extending `StatelessWidget` (or `StatefulWidget` if needed for animations)
- All params from the spec as constructor arguments
- `const` constructor if possible
- Tokens accessed in `build()` via `Theme.of(context).extension<T>()!`

### 2. Test: `test/design_system/foo_bar_test.dart`
- Import the widget and token extensions
- Wrap in `MaterialApp` with theme that includes all token extensions
- Test that the widget renders without errors
- Test key structural elements (e.g., text content appears, tap callbacks fire)
- Use `pumpWidget`, `find.text`, `find.byType`, `tester.tap`

### 3. Barrel export: add to `lib/design_system/design_system.dart`
```dart
export 'src/foo_bar.dart';
```

### 4. Widgetbook story: `widgetbook/lib/stories/foo_bar.stories.dart`
- Import the real widget (never build a replica)
- Use Widgetbook knobs for each constructor parameter
- Provide sensible defaults

## Quality Expectations

Before finishing:
1. Run `dart format lib/design_system/src/foo_bar.dart test/design_system/foo_bar_test.dart`
2. Run `flutter analyze` — no issues in new files
3. Run `flutter test test/design_system/foo_bar_test.dart` — passes
4. No hardcoded color, spacing, radius, elevation, opacity, or sizing values
5. Widget is exported from barrel file
6. Run `bash tool/verify-widget.sh FooBar`

## Mapping Notes

If the spec contains `mapping_notes` with `confidence: nearest`, those values were snapped to the closest token and may not be pixel-perfect. Use the mapped token anyway — the design system prioritizes consistency over pixel-perfection.

## Dart MCP Tools

Use Dart MCP tools at every stage of the build. Do not fall back to shell
commands when an MCP tool exists.

**Before writing code — batch all lookups in ONE parallel call:**
1. Scan the spec for all token classes and existing widgets referenced
2. Make a SINGLE parallel batch of tool calls (one message, multiple tool uses):
   - `resolve_workspace_symbol` for EACH symbol (AppSpacing, AppRadii,
     AppSemanticColors, StatusBadge, IconBadge, AppButton, etc.)
   - `hover` on any token/widget whose API you need to verify
3. Use the results to ground your code — do NOT proceed without confirming
   symbols exist

**After writing ALL output files (widget, test, use case, barrel, catalog):**
- `analyze_files` — run once to catch all issues across new files
- `dart_fix` — auto-fix any fixable issues
- `run_tests` — verify the test passes

Run these post-write checks ONCE after all files are written, not after
each individual file. This avoids redundant analysis runs.

**For formatting:** use `dart_format` MCP tool (not `dart format` shell command).
**For tests:** use `run_tests` MCP tool (not `flutter test` shell command).
The Dart MCP server states: "ALWAYS use instead of `dart test` or `flutter test` shell commands."

## Visual Regression Tests

Goldens are optional and reserved for stable, high-signal primitives where
visual drift would be costly: `Button`, `Tabs`, core navigation, typography
catalogs, token catalogs, and other widgets that are intentionally stable.
Do not add goldens by default for active iteration widgets or one-off page
surfaces; prefer behavior tests plus Widgetbook review until the API settles.

When a golden is warranted, include a focused screenshot assertion:

```dart
testWidgets('golden', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: <theme with all design system extensions>,
      home: Scaffold(body: Center(child: <WidgetName>(<mock params>))),
    ),
  );
  await expectLater(
    find.byType(<WidgetName>),
    matchesGoldenFile('goldens/<widget_name>.png'),
  );
});
```

- Wrap in `MaterialApp` with full theme (all design system ThemeExtensions registered)
- Use `Center` + `Scaffold(body:)` for consistent framing
- Run `flutter test --update-goldens test/design_system/<widget_name>_test.dart` to generate the baseline PNG
- Golden files live at `test/design_system/goldens/` — committed to git
- `tool/verify-widget.sh` does not require goldens; add them only when the
  component is stable enough that visual snapshots improve review quality.

## Genesis Document

Every widget gets a `.genesis.md` file in `lib/design_system/.specs/`:

```markdown
# <WidgetName> — Genesis

## Inspiration
- **Source**: Figma / screenshot / description
- **Figma URL**: <url or "N/A">
- **Reference screenshot**: `<WidgetName>.reference.png`

## Design Decisions

### <Decision title>
- **What Figma showed**: <description>
- **What we implemented**: <description>
- **Why**: <rationale — token snap, design system constraint, accessibility, simplification, etc.>

## Token Mapping
| Figma Value | Design System Token | Notes |
|-------------|-------------------|-------|
| 14px padding | `space16` (16px) | Snapped to nearest spacing token |
| #2563EC | `colorScheme.secondary` | Exact match |

## Optional Visual Reference
- **Widgetbook story**: `widgetbook/lib/stories/<widget_name>.stories.dart`
- **Golden file**: `test/design_system/goldens/<widget_name>.png` when a stable
  primitive intentionally opts into golden coverage
```

Key principles:
- Figma is inspiration, not ground truth — the code and tokens are canonical
- The "why" behind each decision matters more than the "what"
- `mapping_notes` with `confidence: nearest` from the spec must appear as decisions with rationale
- The format is intentionally freeform markdown — decisions are described in prose

## Widget Catalog

After creating a widget, add a row to the Widget Catalog table in `DESIGN_SYSTEM.md`:

```markdown
| `WidgetName` | [Figma](<url>) | [genesis](.specs/WidgetName.genesis.md) |
```

This keeps the living document as the central index of all design system components.
