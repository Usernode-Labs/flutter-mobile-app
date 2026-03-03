# Usernode Mobile App

Flutter mobile app for a Layer 1 blockchain operated from phones.

## Documentation Philosophy

**Code is the documentation.** Doc comments, type signatures, and well-named abstractions are the source of truth. Everything else — markdown files, genesis docs, spec files — is scaffolding that points readers to the right code with just enough context. Never duplicate what the code already says; link to it instead.

## Quick Reference

- **Project guidelines**: `AGENTS.md`
- **Design system (POC)**: `lib/design_system/` — living design system with `DESIGN_SYSTEM.md`
- **Existing widgets**: `lib/core/widgets/` — composable in new design system widgets

## Build & Quality

```bash
flutter pub get
flutter gen-l10n
dart format .
flutter analyze
flutter test
cd packages/ds_lints && dart run bin/lint.dart ../..   # design system lints
```

## Design System Boundary

All new design system work lives in `lib/design_system/`. Existing code is untouched.

- **M3-first rule (TOP PRIORITY)**: Never create a custom widget that duplicates an M3 component (ListTile, Card, Switch, Checkbox, etc.). Use M3 directly and compose DS *slot widgets* (IconBadge, StatusBadge, etc.) into M3 containers. Only create a custom widget when M3 genuinely doesn't cover the pattern — prove the gap first.
- **New widgets**: When M3 doesn't cover the need, build from core primitives with M3 alignment in mind.
- **Composing existing `lib/core/widgets/`** (AppButton, AppCard, etc.) is allowed.
- **Tokens**: Access via `Theme.of(context).extension<T>()!` (e.g., `AppSpacing`, `AppRadii`, `AppElevation`)
- **Colors**: `Theme.of(context).colorScheme`
- **Typography**: `Theme.of(context).textTheme`
- **Presentation-only**: Design system widgets take all state via constructor params (data + callbacks). No providers, no `ConsumerWidget`, no services. No FRB-generated types in constructor params (they transitively import native FFI). Screens in `lib/features/` wire state to widgets.
- **Widgetbook rule**: Every new design system widget gets a use case that imports the **real widget** with mock data via knobs — never hand-built replicas.
- **Quality gate**: `dart format` clean, `flutter analyze` passes, tests pass, `ds_lints` clean (no warnings)
