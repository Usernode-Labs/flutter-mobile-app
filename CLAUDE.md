# Usernode Mobile App

Flutter mobile app for a Layer 1 blockchain operated from phones.

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
```

## Design System Boundary

All new design system work lives in `lib/design_system/`. Existing code is untouched.

- **New widgets**: Prefer M3 Material components for native style, accessibility, and consistency. When M3 doesn't cover the need, build from core primitives with M3 alignment in mind.
- **Composing existing `lib/core/widgets/`** (AppButton, AppCard, etc.) is allowed.
- **Tokens**: Access via `Theme.of(context).extension<T>()!` (e.g., `AppSpacing`, `AppRadii`, `AppElevation`)
- **Colors**: `Theme.of(context).colorScheme`
- **Typography**: `Theme.of(context).textTheme`
- **Presentation-only**: Design system widgets take all state via constructor params (data + callbacks). No providers, no `ConsumerWidget`, no services. No FRB-generated types in constructor params (they transitively import native FFI). Screens in `lib/features/` wire state to widgets.
- **Widgetbook rule**: Every new design system widget gets a use case that imports the **real widget** with mock data via knobs — never hand-built replicas.
- **Quality gate**: `dart format` clean, `flutter analyze` passes, tests pass
