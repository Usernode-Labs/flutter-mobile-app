# Widget Build Instructions

Read a `.spec.yaml` file from this directory and produce a complete design system widget.

## Design System Constraints

### Allowed primitives
Use only Flutter core primitives for layout and styling:
- Layout: `Container`, `Padding`, `Row`, `Column`, `Stack`, `Wrap`, `SizedBox`, `Expanded`, `Flexible`, `Spacer`, `Align`, `Center`, `AspectRatio`, `FractionallySizedBox`, `ConstrainedBox`, `IntrinsicHeight`, `IntrinsicWidth`
- Interaction: `GestureDetector`, `InkWell`
- Animation: `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSwitcher`, `AnimatedCrossFade`
- Painting: `CustomPaint`, `DecoratedBox`, `ClipRRect`, `ClipOval`, `Opacity`
- Scrolling: `SingleChildScrollView`, `ListView.builder`

### Banned widgets
Never use Material or Cupertino widgets in new design system code:
- Banned: `ElevatedButton`, `TextButton`, `OutlinedButton`, `IconButton`, `FloatingActionButton`, `Card`, `ListTile`, `Scaffold`, `AppBar`, `BottomNavigationBar`, `Drawer`, `Dialog`, `SnackBar`, `Chip`, `Switch`, `Checkbox`, `Radio`, `Slider`, `TabBar`, `NavigationBar`, `NavigationRail`, `DropdownButton`, `PopupMenuButton`, `ExpansionTile`, `DataTable`, `CupertinoButton`, `CupertinoNavigationBar`, `CupertinoSwitch`

### Exceptions
These are allowed in new widgets:
- `Text`, `Icon`, `InkWell`, `DefaultTextStyle`
- Composing existing widgets from `lib/core/widgets/` (e.g., `AppButton`, `AppCard`)

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

### 4. Widgetbook use case: `widgetbook/lib/use_cases/foo_bar_use_case.dart`
- Import the real widget (never build a replica)
- Use Widgetbook knobs for each constructor parameter
- Provide sensible defaults

## Quality Expectations

Before finishing:
1. Run `dart format lib/design_system/src/foo_bar.dart test/design_system/foo_bar_test.dart`
2. Run `flutter analyze` — no issues in new files
3. Run `flutter test test/design_system/foo_bar_test.dart` — passes
4. No hardcoded color, spacing, radius, elevation, opacity, or sizing values
5. No banned Material/Cupertino widgets
6. Widget is exported from barrel file

## Mapping Notes

If the spec contains `mapping_notes` with `confidence: nearest`, those values were snapped to the closest token and may not be pixel-perfect. Use the mapped token anyway — the design system prioritizes consistency over pixel-perfection.
