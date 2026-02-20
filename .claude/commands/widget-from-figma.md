Create a widget from a Figma design or visual reference.

## Input

$ARGUMENTS

## Routing

Detect whether the input is a Figma URL or a screenshot/description.

### Path A — Figma URL detected

If the input contains `figma.com/design/`:

**Step 1: Inspect Figma and generate spec**

Run `/figma-inspect` with the Figma URL. This calls the Figma MCP, maps tokens, and writes a `.spec.yaml` to `lib/design_system/.specs/`.

**Step 2: Build the widget**

Read the generated spec file and `lib/design_system/.specs/BUILD_INSTRUCTIONS.md`. Build the widget following those instructions exactly.

During the build, use Dart MCP tools to ground your work:
- Resolve token APIs and widget signatures via symbol lookup
- Run diagnostics on written files to catch issues early
- Look up documentation for any unfamiliar Flutter APIs

Produce all required output files: widget, test, barrel export, and Widgetbook use case.

**Step 3: Verify the widget**

Run `/verify-widget` targeting the newly created widget. If any checks fail:

1. Read the failure details
2. Fix the issues directly (format, analyze, missing export, hardcoded values, banned widgets)
3. Re-run `/verify-widget` to confirm all 6 checks pass

Report the final result to the user.

### Path B — Screenshot or description

If the input is a screenshot path, image, or text description (not a Figma URL):

1. Read `lib/design_system/DESIGN_SYSTEM.md` — constraints and decisions
2. Read `lib/design_system/design_system.dart` — current exports
3. Read `lib/design_system/tokens/` — available token vocabulary
4. Read `lib/core/widgets/` — existing widgets available for composition
5. Read `lib/design_system/.specs/BUILD_INSTRUCTIONS.md` — build constraints and token-to-code reference
6. Build the widget directly based on the visual reference, using Dart MCP tools to resolve symbols and run diagnostics
7. Run `/verify-widget` to validate

## Context to Read First

1. `lib/design_system/DESIGN_SYSTEM.md` — constraints and captured decisions
2. `lib/design_system/design_system.dart` — current exports
3. `lib/design_system/tokens/` — available token vocabulary
4. `lib/core/widgets/` — existing widgets available for composition
