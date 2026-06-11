---
name: usernode-ds-build-widget
description: Build or revise Usernode design-system widgets from normalized design input. Use for DS component work in lib/design_system, including Figma/screenshot/sketch/text-intake pipelines.
---

# Usernode DS Build Widget

Build presentation-only design-system widgets in `lib/design_system/`.

## Required Reading

- `lib/design_system/DESIGN_SYSTEM.md`
- `lib/design_system/docs/CONSTRAINTS.md`
- `lib/design_system/.specs/BUILD_INSTRUCTIONS.md`
- `lib/design_system/docs/LAYOUT.md` when layout or scroll behavior matters

## Pipeline

1. Intake: use `usernode-ds-design-intake` unless a complete spec already exists.
2. Pattern decision: apply `usernode-mobile-ux-taste`; design work must have `pattern_decision`.
3. Match before make:
   - Check Flutter Material 3 first.
   - Check existing DS exports in `lib/design_system/design_system.dart`.
   - Check composable core widgets where appropriate.
4. If no match exists, stop and present a gap proof. Create a new pattern only after explicit human approval.
5. Implement only after the decision is clear:
   - widget in `lib/design_system/src/<snake>.dart`;
   - focused test in `test/design_system/<snake>_test.dart`;
   - real Widgetbook story in `widgetbook/lib/stories/<snake>.stories.dart`;
   - barrel export in `lib/design_system/design_system.dart`;
   - genesis doc in `lib/design_system/.specs/<WidgetName>.genesis.md`;
   - catalog row in `lib/design_system/DESIGN_SYSTEM.md`.
6. Verify:

   ```bash
   bash tool/verify-widget.sh <WidgetName>
   ```

## Constraints

- Widgets are presentation-only: no providers, services, async orchestration, or FRB-generated constructor types.
- Use `Theme.of(context).extension<T>()!` for DS tokens and `Theme.of(context).textTheme` for typography.
- Use M3 components directly at screen level. DS widgets should be slot widgets or genuine custom gaps, not wrappers around M3 containers.
- Use `widgetbook/lib/stories/`, not stale `lib/design_system/widgetbook/` or `widgetbook/lib/use_cases/`.
- For text-only inputs, proceed only after explicit user override and preserve uncertainty in `pattern_decision`.
