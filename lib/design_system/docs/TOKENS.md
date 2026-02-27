# Token Reference

Design tokens are accessed via `ThemeExtension`s registered on the app theme.
Every token class extends `ThemeExtension<T>`, supports `copyWith` and `lerp`,
and is retrieved with:

```dart
final spacing = Theme.of(context).extension<AppSpacing>()!;
```

> **Colors & typography** use the standard M3 accessors
> (`Theme.of(context).colorScheme` / `Theme.of(context).textTheme`) and are
> documented separately.

---

## AppSpacing

Multiples of 4 aligned to the M3 4-dp grid.

| Token | Value |
|-------|-------|
| `space4` | 4 |
| `space8` | 8 |
| `space12` | 12 |
| `space16` | 16 |
| `space24` | 24 |
| `space32` | 32 |
| `space48` | 48 |

```dart
final spacing = Theme.of(context).extension<AppSpacing>()!;
Padding(padding: EdgeInsets.all(spacing.space16));
```

Source: `lib/design_system/tokens/app_spacing.dart`

---

## AppRadii

Corner radii for `BorderRadius`. Convenience getters (`borderRadiusSmall`,
`borderRadiusTopLarge`, etc.) return pre-built `BorderRadius` objects.

| Token | Value |
|-------|-------|
| `small` | 8 |
| `medium` | 12 |
| `large` | 16 |
| `largeIncreased` | 20 |
| `xLarge` | 24 |
| `full` | 999 |

```dart
final radii = Theme.of(context).extension<AppRadii>()!;
ClipRRect(borderRadius: radii.borderRadiusMedium, child: ...);
```

Source: `lib/design_system/tokens/app_radii.dart`

---

## AppElevation

Material elevation values following a flat-first philosophy — most surfaces use
`none` or `low`. Reserve `high` and `max` for popovers and modals.

| Token | Value |
|-------|-------|
| `none` | 0 |
| `low` | 1 |
| `medium` | 2 |
| `high` | 4 |
| `max` | 8 |

```dart
final elevation = Theme.of(context).extension<AppElevation>()!;
Card(elevation: elevation.low, child: ...);
```

Source: `lib/design_system/tokens/app_elevation.dart`

---

## AppOpacity

Opacity multipliers for overlays, disabled states, and secondary content.

| Token | Value |
|-------|-------|
| `subtle` | 0.08 |
| `medium` | 0.12 |
| `strong` | 0.20 |
| `disabled` | 0.30 |
| `secondary` | 0.40 |

```dart
final opacity = Theme.of(context).extension<AppOpacity>()!;
Opacity(opacity: opacity.disabled, child: ...);
```

Source: `lib/design_system/tokens/app_opacity.dart`

---

## AppSizing

Fixed sizes for icon containers, icons, and buttons. Container sizes define tap
targets; icon sizes define the visual glyph inside.

### Icon Containers

| Token | Value | Note |
|-------|-------|------|
| `iconContainerSmall` | 40 | |
| `iconContainerRegular` | 48 | Minimum accessible tap target |
| `iconContainerLarge` | 56 | Prominent actions |
| `iconContainerXLarge` | 64 | FAB / primary actions |

### Icons

| Token | Value |
|-------|-------|
| `iconSmall` | 20 |
| `iconRegular` | 24 |
| `iconLarge` | 28 |
| `iconXLarge` | 32 |

### Button Heights

| Token | Value |
|-------|-------|
| `buttonHeightSmall` | 40 |
| `buttonHeightRegular` | 48 |
| `buttonHeightLarge` | 56 |

```dart
final sizing = Theme.of(context).extension<AppSizing>()!;
SizedBox(
  width: sizing.iconContainerRegular,
  height: sizing.iconContainerRegular,
  child: Icon(Icons.star, size: sizing.iconRegular),
);
```

Source: `lib/design_system/tokens/app_sizing.dart`

---

## AppAnimation

Duration tokens aligned with M3 motion guidance. Durations snap at the lerp
midpoint rather than interpolating (durations don't lerp smoothly).

| Token | Value | Use |
|-------|-------|-----|
| `fast` | 100 ms | Micro-interactions |
| `normal` | 150 ms | Standard UI transitions |
| `slow` | 200 ms | Complex animations |
| `complex` | 300 ms | Page transitions |

```dart
final anim = Theme.of(context).extension<AppAnimation>()!;
AnimatedOpacity(duration: anim.normal, opacity: 1.0, child: ...);
```

Source: `lib/design_system/tokens/app_animation.dart`

---

## AppSemanticColors

Four domain-specific color groups — `technical`, `flash`, `community`, and
`success` — each containing the M3 quad: `color`, `onColor`, `colorContainer`,
`onColorContainer`. Six contrast variants are provided (light, lightMedium,
lightHigh, dark, darkMedium, darkHigh).

```dart
final semantic = Theme.of(context).extension<AppSemanticColors>()!;
Container(
  color: semantic.technical.colorContainer,
  child: Text('Tech', style: TextStyle(color: semantic.technical.onColorContainer)),
);
```

For full color values and contrast tables see [COLOR.md](COLOR.md).

Source: `lib/design_system/tokens/app_semantic_colors.dart`
