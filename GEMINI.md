# Usernode Mobile App

Flutter mobile app for a Layer 1 blockchain operated from phones.

## Quick Reference

- **Project guidelines**: `docs/AGENTS.md`
- **Design system (POC)**: `lib/design_system/` — living design system with `DESIGN_SYSTEM.md`
- **Existing widgets**: `lib/core/widgets/` — composable in new design system widgets

## Build & Quality

```bash
flutter pub get
flutter gen-l10n
dart format .
flutter analyze
flutter test
```

## Design System Boundary

All new design system work lives in `lib/design_system/`. Existing code is untouched.

- **New widgets**: Use Flutter core primitives (Container, Padding, Row, Column, GestureDetector, AnimatedContainer, CustomPaint, etc.)
- **Not allowed in new widgets**: Material widgets (ElevatedButton, Card, ListTile, etc.) or Cupertino widgets
- **Exceptions**: `Text`, `Icon`, `InkWell`, `DefaultTextStyle` are allowed. Composing existing `lib/core/widgets/` (AppButton, AppCard, etc.) is allowed.
- **Tokens**: Access via `Theme.of(context).extension<T>()!` (e.g., `AppSpacing`, `AppRadii`, `AppElevation`)
- **Colors**: `Theme.of(context).colorScheme`
- **Typography**: `Theme.of(context).textTheme`
- **Quality gate**: `dart format` clean, `flutter analyze` passes, tests pass

## Gemini CLI Notes

- Use `/modify` for targeted edits to existing files
- Use `/commit` for conventional commits (feat:, fix:, chore:)
- Read `lib/design_system/DESIGN_SYSTEM.md` before creating any new widget
- Place new widgets in `lib/design_system/src/`
- Export new widgets from `lib/design_system/design_system.dart`

## Spec-Driven Widget Pipeline

When invoked headlessly by Claude via `gemini -p "..." --yolo`, you may receive a task to build a widget from a `.spec.yaml` file.

### How it works

1. Claude inspects a Figma design and writes a structured spec to `lib/design_system/.specs/<WidgetName>.spec.yaml`
2. Claude invokes you with a prompt pointing to the spec file and `lib/design_system/.specs/BUILD_INSTRUCTIONS.md`
3. You read both files and build the widget following BUILD_INSTRUCTIONS.md exactly
4. Claude runs verification checks after you finish

### Your responsibilities

- Read the spec YAML carefully — it contains the complete layout tree, token mappings, and constructor params
- Follow `BUILD_INSTRUCTIONS.md` for all constraints, token-to-code mappings, and required output files
- Produce: widget file, test file, barrel export, and Widgetbook use case
- Run `dart format` and `flutter analyze` before finishing
- Never use Material/Cupertino widgets (see constraints in BUILD_INSTRUCTIONS.md)
- All colors, spacing, radii, elevation, opacity, and sizing must use tokens — no hardcoded values
