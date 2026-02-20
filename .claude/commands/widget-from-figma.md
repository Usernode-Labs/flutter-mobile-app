Create a widget from a visual reference (screenshot, Figma export, or description).

## Desired End State

A valid widget in `lib/design_system/src/` that:
- Faithfully represents the visual input provided
- Uses only Flutter core primitives + ThemeExtension tokens
- Colors from `Theme.of(context).colorScheme`, typography from `Theme.of(context).textTheme`
- No hardcoded color/spacing/radius values — all via tokens
- Has a passing widget test in `test/design_system/`
- Is exported from `lib/design_system/design_system.dart`
- Passes `dart format`, `flutter analyze`, and `flutter test`

## Context to Read First

1. `lib/design_system/DESIGN_SYSTEM.md` — constraints and captured decisions
2. `lib/design_system/design_system.dart` — current exports
3. `lib/design_system/tokens/` — available token vocabulary
4. `lib/core/widgets/` — existing widgets available for composition

## Approach

You have full autonomy on how to build the widget. Decide the best structure, naming, and composition. Follow the constraints, use the token vocabulary, and verify quality.

Input: $ARGUMENTS
