Create a widget from a Figma design or visual reference using the agent pipeline.

## Input

$ARGUMENTS

## Routing

Detect whether the input is a Figma URL or a screenshot/description.

### Path A — Figma URL detected

If the input contains `figma.com/design/`:

**Step 1: Inspect Figma and generate spec**

Run `/figma-inspect` with the Figma URL. This calls the Figma MCP, maps tokens, and writes a `.spec.yaml` to `lib/design_system/.specs/`.

**Step 2: Invoke Gemini to build the widget**

Read the generated spec file to get the widget name and path. Then invoke Gemini headlessly:

```bash
gemini -p "Read the design spec at lib/design_system/.specs/<WidgetName>.spec.yaml and the build instructions at lib/design_system/.specs/BUILD_INSTRUCTIONS.md. Build the widget following those instructions exactly." --yolo
```

Wait for Gemini to complete.

**Step 3: Verify the widget**

Run `/verify-widget` targeting the newly created widget. If any checks fail:

1. Read the failure details
2. Fix the issues directly (format, analyze, missing export, hardcoded values, banned widgets)
3. Re-run `/verify-widget` to confirm all 6 checks pass

Report the final result to the user.

### Path B — Screenshot or description

If the input is a screenshot path, image, or text description (not a Figma URL):

Fall back to the single-shot approach:

1. Read `lib/design_system/DESIGN_SYSTEM.md` — constraints and decisions
2. Read `lib/design_system/design_system.dart` — current exports
3. Read `lib/design_system/tokens/` — available token vocabulary
4. Read `lib/core/widgets/` — existing widgets available for composition
5. Build the widget directly based on the visual reference
6. Run `/verify-widget` to validate

## Context to Read First

1. `lib/design_system/DESIGN_SYSTEM.md` — constraints and captured decisions
2. `lib/design_system/design_system.dart` — current exports
3. `lib/design_system/tokens/` — available token vocabulary
4. `lib/core/widgets/` — existing widgets available for composition
