---
name: widgetbook-v4
description: >
  Write, test, and maintain Widgetbook v4 stories with typed Args and
  Scenarios for the Usernode design system. Use this skill whenever you
  create a new DS widget, modify a widget constructor, write or update
  story files, add visual regression scenarios, set up golden tests, or
  work on any task involving the widgetbook/ workspace. Also use when the
  user mentions "story", "stories", "catalog", "visual regression",
  "golden test", "Widgetbook", or wants to verify a widget renders
  correctly across themes.
---

# Widgetbook v4 — Usernode Design System

Story files are the machine-readable specification of the design system.
Agents read them to discover widgets, understand constructor signatures,
and learn valid usage patterns. Every DS widget must have a story file
with Scenarios — a story without Scenarios produces zero test coverage.

## Before you write anything

Scan the catalog to understand what exists:

```bash
find widgetbook/lib/stories -name "*.stories.dart" | sort
```

From each file, extract:
- `Meta<T>` — which widget exists and its path in the catalog
- `_Args(...)` — exact constructor parameters with types
- `_Scenario(...)` — which states matter for this widget
- Doc comments on the widget class — design intent and usage rules

This context prevents you from reinventing widgets that exist or
guessing constructor signatures. Read before you write.

## Workspace

```
widgetbook/                          # separate Flutter package
  lib/
    main.dart                        # entry point with Config + 6 themes
    components.g.dart                # auto-generated component registry
    stories/
      button.stories.dart            # hand-written
      button.stories.g.dart          # generated (_Story, _Args, _Scenario)
  pubspec.yaml                       # depends on crypto_mobile_app via path
```

Commands:
```bash
cd widgetbook && dart run build_runner build -d   # generate types
cd widgetbook && flutter run -d chrome            # run catalog
cd widgetbook && flutter test --update-goldens    # generate baselines
cd widgetbook && flutter test                     # visual regression
```

Widgets are imported from the main app:
```dart
import 'package:crypto_mobile_app/design_system/src/button.dart';
```

## Story file anatomy

```dart
import 'package:flutter/material.dart';  // REQUIRED — generated code needs Key, etc.
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/my_widget.dart';

part 'my_widget.stories.g.dart';  // REQUIRED — codegen writes _Story, _Args here

const meta = Meta<MyWidget>(path: 'widgets/category');

final $Default = _Story(
  name: 'Default',
  args: _Args(
    label: StringArg('Example'),
    variant: EnumArg(MyVariant.primary, values: MyVariant.values),
    onTap: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(name: 'Primary', args: _Args(/* override specific args */)),
    _Scenario(name: 'Disabled', args: _Args(isEnabled: BoolArg(false))),
  ],
);
```

After writing or modifying: `dart run build_runner build -d` to regenerate.

## Args

The generator creates `_Args` from the widget constructor. Map each param:

| Param type | Arg | Notes |
|---|---|---|
| `String` | `StringArg('value')` | |
| `bool` | `BoolArg(true)` | |
| `int` | `IntArg(0)` | |
| `double` | `DoubleArg(0.0)` | |
| `double` (0–1) | `DoubleArg(0.5, style: SliderDoubleArgStyle(min: 0, max: 1, divisions: 20))` | |
| `enum` | `EnumArg(E.value, values: E.values)` | `values:` is **required** |
| `VoidCallback?` | `Arg.fixed(() {})` | Never expose callbacks as interactive |
| `Widget?` | `Arg.fixed(const MyWidget())` | |
| `List<T>` | `Arg.fixed([...])` | |
| `String?` (nullable) | `Arg.fixed('value')` or `Arg.fixed(null)` | |

For gallery/composition stories where all args are fixed, use `_Args.fixed()`:
```dart
args: _Args.fixed(label: 'Hello', variant: MyVariant.primary, onTap: () {}),
```

## Scenarios — the testing mechanism

Every story **must** have scenarios. They auto-generate snapshots via
`flutter test`. Without them, the widget has zero visual regression coverage.

Minimum per widget:
- Default state
- Each enum variant that changes appearance
- Disabled/inactive (if applicable)
- Loading (if applicable)
- Error/empty (if applicable)

Scenarios can pin themes for cross-theme regression:

```dart
scenarios: [
  _Scenario(
    name: 'Active - Light',
    args: _Args(variant: EnumArg(CardVariant.active, values: CardVariant.values)),
    modes: [MaterialThemeMode('Light', lightTheme)],
  ),
  _Scenario(
    name: 'Active - Dark',
    args: _Args(variant: EnumArg(CardVariant.active, values: CardVariant.values)),
    modes: [MaterialThemeMode('Dark', darkTheme)],
  ),
],
```

For interaction testing, use `run`:

```dart
_Scenario(
  name: 'Tap increments counter',
  run: (tester, args) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  },
),
```

## Sliver widgets

Slivers (TopAppBar, etc.) can't render standalone. Use `setup` to wrap:

```dart
final $Small = _Story(
  args: _Args(title: StringArg('Challenges')),
  setup: (context, child, args) {
    return Material(
      child: CustomScrollView(slivers: [
        child,
        const SliverFillRemaining(child: Center(child: Text('Content'))),
      ]),
    );
  },
);
```

The `Material` ancestor is required — `ListTile` and other M3 widgets
crash without one. The `setup` wraps the widget; the `builder` returns it.

## Widget doc comments

Dart doc comments on the widget class are surfaced automatically as
component documentation in the Widgetbook catalog via `DartCommentDocBlock`.
Write them once on the class — Widgetbook handles the rest.

Good doc comments for agents include:
- What the widget is for (one sentence)
- When to use it vs alternatives
- Composition guidance (what parent containers it belongs in)

```dart
/// Displays a challenge summary card with category icon, title, and reward.
///
/// Use inside ListView.separated or PSL surfaceSlivers. Pair with Tabs
/// for category filtering. Never use standalone outside a scrollable
/// container.
///
/// Four lifecycle variants: active, ongoing, completed, missed.
class ChallengeCard extends StatefulWidget { ... }
```

## The agentic workflow

When creating or modifying a DS widget:

1. **Discover** — scan `*.stories.dart` to find existing widgets and patterns
2. **Generate** — write the widget using DS tokens, M3 containers, presentation-only
3. **Story** — write the `.stories.dart` file with Args + Scenarios immediately
4. **Codegen** — `dart run build_runner build -d`
5. **Test** — `flutter test` — read failures, fix the widget, repeat
6. **Done** — all scenarios pass, then commit

The feedback loop (step 5) is the key differentiator. Scenario failures give
structured, actionable output — which scenario failed and which assertion.
Fix and rerun until clean. No human needed for this loop.

## Themes (6 configured)

Light, Light Medium Contrast, Light High Contrast,
Dark, Dark Medium Contrast, Dark High Contrast.

All from `ColorIsExpensiveTheme` + `AppSemanticColors`. ColorScheme roles
are achromatic grey — chromatic color only via `AppSemanticColors`.

## DS conventions (always follow)

- **M3-first**: Use M3 directly (ListTile, Card, Switch). DS slot widgets
  (IconBadge, StatusBadge) compose INTO M3 containers. Never wrap M3.
- **Presentation-only**: No providers, no ConsumerWidget, no FRB types.
  Data in via constructor, pixels out.
- **Tokens**: `Theme.of(context).extension<AppSpacing>()!`, `.colorScheme`,
  `.textTheme`. No hardcoded hex, dp, or magic numbers.
- **Icons**: `Symbols.*_sharp` from material_symbols_icons. Weight 300,
  outline (fill 0), 24px default.
- **Surfaces**: Grey scaffold (`surface`) + white content
  (`surfaceContainerLowest`). No elevation for separation.

See `DESIGN.md` for full token values. See `CLAUDE.md` for all rules.

## Real examples from this codebase

### Simple widget — Button

```dart
// widgetbook/lib/stories/button.stories.dart
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/button.dart';

part 'button.stories.g.dart';

const meta = Meta<Button>(path: 'widgets/buttons');

final $Playground = _Story(
  name: 'Playground',
  args: _Args(
    label: StringArg('View in Leaderboard'),
    size: EnumArg(ButtonSize.regular, values: ButtonSize.values),
    variant: EnumArg(ButtonVariant.tonal, values: ButtonVariant.values),
    isLoading: BoolArg(false),
    leadingIcon: Arg.fixed(null),
    onTap: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(name: 'Primary', args: _Args(
      variant: EnumArg(ButtonVariant.primary, values: ButtonVariant.values),
    )),
    _Scenario(name: 'Outlined', args: _Args(
      variant: EnumArg(ButtonVariant.outlined, values: ButtonVariant.values),
    )),
    _Scenario(name: 'Loading', args: _Args(isLoading: BoolArg(true))),
  ],
);
```

### Multi-variant widget — ChallengeCard

```dart
// widgetbook/lib/stories/challenge_card.stories.dart
// One story per lifecycle variant, each with its own scenarios.
final $Default = _Story(
  name: 'Default',
  args: _Args(
    title: StringArg('Produce Blocks'),
    category: EnumArg(ChallengeCategory.technical, values: ChallengeCategory.values),
    variant: EnumArg(ChallengeCardVariant.active, values: ChallengeCardVariant.values),
    categoryIcon: Arg.fixed(
      const ChallengeCategoryIcon(category: ChallengeCategory.technical),
    ),
    onTap: Arg.fixed(() {}),
    // ... other string args
  ),
  scenarios: [
    _Scenario(name: 'Active - Technical', args: _Args(
      variant: EnumArg(ChallengeCardVariant.active, values: ChallengeCardVariant.values),
      category: EnumArg(ChallengeCategory.technical, values: ChallengeCategory.values),
    )),
    _Scenario(name: 'Missed - Flash', args: _Args(
      variant: EnumArg(ChallengeCardVariant.missed, values: ChallengeCardVariant.values),
      category: EnumArg(ChallengeCategory.flash, values: ChallengeCategory.values),
    )),
  ],
);
```

### Sliver widget — TopAppBar

```dart
// widgetbook/lib/stories/top_app_bar.stories.dart
// Sliver needs setup wrapper with Material + CustomScrollView.
final $Large = _Story(
  name: 'Large',
  args: _Args(
    title: StringArg('Block Production'),
    size: EnumArg(TopAppBarSize.large, values: TopAppBarSize.values),
    subtitle: Arg.fixed('Mar 1 – Mar 31 · Technical'),
    onLeadingTap: Arg.fixed(() {}),
  ),
  setup: (context, child, args) {
    return Material(
      child: CustomScrollView(slivers: [
        child,
        SliverList(delegate: SliverChildBuilderDelegate(
          (context, index) => ListTile(title: Text('Item $index')),
          childCount: 30,
        )),
      ]),
    );
  },
  scenarios: [
    _Scenario(name: 'Small', args: _Args(
      size: EnumArg(TopAppBarSize.small, values: TopAppBarSize.values),
    )),
    _Scenario(name: 'Large with subtitle', args: _Args(
      size: EnumArg(TopAppBarSize.large, values: TopAppBarSize.values),
    )),
  ],
);
```

## Common mistakes

**Forgetting `import 'package:flutter/material.dart'`** — Generated code
uses `Key` and other Flutter types. Without this import, the `.g.dart`
file won't compile. Every story file needs it.

**`EnumArg` without `values:`** — Unlike other Args, `EnumArg` requires
the `values:` parameter: `EnumArg(E.value, values: E.values)`.

**Stories with no Scenarios** — A story renders in the catalog but produces
zero automated test coverage. Always add scenarios.

**Callbacks as interactive args** — Use `Arg.fixed(() {})` for all
`VoidCallback?`, `ValueChanged<T>?`, `Function?` params.

**Using raw Material widgets** — Scan the catalog first. If `Button` exists,
use it instead of `FilledButton`. If `AppSpacing` exists, use it instead of
`SizedBox(height: 16)`.

**Sliver without `Material` in setup** — `ListTile` and other M3 widgets
crash with "No Material widget found" if setup doesn't include `Material`.

**Duplicate `Meta<T>` for the same widget** — Two story files using
`Meta<SameWidget>` causes a collision in `components.g.dart`. Use a wrapper
widget with a distinct Meta if you need multiple story files for one widget.
