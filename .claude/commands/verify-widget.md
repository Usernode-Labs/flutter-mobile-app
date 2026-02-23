Verify a design system widget meets all quality criteria.

## Verifiable Criteria

For each widget in `lib/design_system/src/`, check and report pass/fail:

1. **Format**: Use `dart_format` MCP tool on the widget file — clean
2. **Analyze**: Use `analyze_files` MCP tool — no issues in the widget file
3. **Tests**: Use `run_tests` MCP tool on the widget's test file — passes. Golden tests (tagged `golden`) are excluded by default and only run during `/widget-from-figma`. Pass `--tags golden` to include them explicitly.
4. **No hardcoded values**: No literal numbers for colors, spacing, radius, elevation, opacity, sizing, or animation durations. All must come from ThemeExtension tokens or colorScheme/textTheme.
5. **No banned widgets**: No Material widgets (ElevatedButton, Card, ListTile, Scaffold, AppBar, etc.) or Cupertino widgets. Exceptions: Text, Icon, InkWell, DefaultTextStyle, composing lib/core/widgets/.
6. **Exported**: Widget is exported from `lib/design_system/design_system.dart`
7. **Golden screenshot**: `test/design_system/goldens/<widget_name>.png` must exist. Golden tests are **not re-run** during verify — they are only generated/updated during `/widget-from-figma`. To update goldens manually: `flutter test --update-goldens --tags golden test/design_system/<widget_name>_test.dart`
8. **Genesis document & visual review**:
   - `lib/design_system/.specs/<WidgetName>.genesis.md` must exist
   - Must have an Inspiration section with source identified
   - Must have a Design Decisions section (can note "No deviations — exact token matches" if applicable)
   - Read the Figma reference PNG (`lib/design_system/.specs/<WidgetName>.reference.png`) and the golden PNG (`test/design_system/goldens/<widget_name>.png`) using Claude multimodal
   - Visually compare: do the documented decisions account for the visible differences?
   - If there are significant structural differences not documented in the genesis, flag them

If no spec YAML exists for the widget, checks 7-8 are skipped (backward compatibility with widgets created before this pipeline).

9. **Widget Catalog entry**: The widget must have a row in the Widget Catalog table in `lib/design_system/DESIGN_SYSTEM.md`. Check that the PascalCase widget name appears in the table.

10. **Human visual review (Widgetbook)**:
   - After all automated checks pass, launch Widgetbook so the user can inspect the widget in-browser
   - Run: `flutter run -d chrome -t lib/design_system/widgetbook/widgetbook.dart` (in background)
   - Wait for the app to be serving, then tell the user Widgetbook is running and which widget/use case to navigate to
   - This is the final gate — the user confirms the widget looks correct or requests changes

## Output

Report each automated criterion (1-9) as PASS or FAIL with details for failures.
After all pass, launch Widgetbook and ask the user to visually verify.

Target: $ARGUMENTS (widget name or "all" for all widgets in src/)
