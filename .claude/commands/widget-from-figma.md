Create a widget from a Figma design or visual reference.

## Input

$ARGUMENTS

## Routing

Detect whether the input is a Figma URL or a screenshot/description.

### Path A — Figma URL detected

If the input contains `figma.com/design/`:

**Step 1: Inspect Figma and generate spec**

Run `/figma-inspect` with the Figma URL. This calls the Figma MCP, maps tokens, and writes a `.spec.yaml` and `.reference.png` to `lib/design_system/.specs/`.

**Step 2: Build the widget**

Read the generated spec file, the reference screenshot at `meta.reference_screenshot`, and `lib/design_system/.specs/BUILD_INSTRUCTIONS.md`. Build the widget following those instructions exactly. Treat the reference screenshot as design inspiration, not a pixel-perfect target.

Use Dart MCP tools throughout the build:

Before writing code:
- `resolve_workspace_symbol` — look up tokens (AppSpacing, AppRadii, etc.)
  and existing widgets before using them. Catches typos, confirms APIs exist.
- `hover` — get docs and type info for any token or widget you plan to compose.
- `signature_help` — verify constructor signatures of lib/core/widgets/
  components before composing them.

After writing each file:
- `analyze_files` — run analysis to catch type errors, missing imports,
  and lint issues before moving to the next file.
- `dart_fix` — auto-fix any fixable issues found by analysis.

Produce all required output files: widget, test (with golden assertion), barrel export, and Widgetbook use case.

**Golden test** — when generating the widget's test file, include a golden assertion:
```dart
testWidgets('golden', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: <theme with all design system extensions>,
      home: Scaffold(body: Center(child: <WidgetName>(<mock params>))),
    ),
  );
  await expectLater(
    find.byType(<WidgetName>),
    matchesGoldenFile('goldens/<widget_name>.png'),
  );
});
```
After writing the test, run `flutter test --update-goldens test/design_system/<widget_name>_test.dart` to generate the baseline PNG.

**Write the genesis document** at `lib/design_system/.specs/<WidgetName>.genesis.md`:
- Record the inspiration source (Figma URL, screenshot, description)
- For each place where the implementation differs from the inspiration, write a decision entry explaining what, how, and why
- Include a token mapping table showing Figma values → design system tokens
- Reference the golden file path
- If `mapping_notes` in the spec have `confidence: nearest`, promote those into the decisions section with rationale

**Update the Widget Catalog** in `DESIGN_SYSTEM.md` — add a row to the table with widget name, source link, and genesis link.

**Step 3: Verify the widget**

Run `/verify-widget` targeting the newly created widget. If any checks fail:

1. Read the failure details
2. Fix the issues directly (format, analyze, missing export, hardcoded values, banned widgets)
3. Re-run `/verify-widget` to confirm all 8 checks pass

Report the final result to the user.

### Path B — Screenshot or description

If the input is a screenshot path, image, or text description (not a Figma URL):

1. Read `lib/design_system/DESIGN_SYSTEM.md` — constraints, philosophy, and decisions
2. Read `lib/design_system/design_system.dart` — current exports
3. Read `lib/design_system/tokens/` — available token vocabulary
4. Read `lib/core/widgets/` — existing widgets available for composition
5. Read `lib/design_system/.specs/BUILD_INSTRUCTIONS.md` — build constraints and token-to-code reference
6. Save the input screenshot (if provided) as `lib/design_system/.specs/<WidgetName>.reference.png`
7. Create a minimal `.spec.yaml` with `meta` section (widget name, description, date, reference_screenshot)
8. Build the widget directly based on the visual reference, using Dart MCP tools to resolve symbols and run diagnostics
9. Include golden test assertion in the test file; run `flutter test --update-goldens` to generate baseline PNG
10. Write the genesis document at `lib/design_system/.specs/<WidgetName>.genesis.md`
11. Update the Widget Catalog in `DESIGN_SYSTEM.md`
12. Run `/verify-widget` to validate

## Context to Read First

1. `lib/design_system/DESIGN_SYSTEM.md` — philosophy, constraints, catalog, and captured decisions
2. `lib/design_system/design_system.dart` — current exports
3. `lib/design_system/tokens/` — available token vocabulary
4. `lib/core/widgets/` — existing widgets available for composition
5. `lib/design_system/.specs/<WidgetName>.reference.png` — Figma inspiration screenshot (if available)
