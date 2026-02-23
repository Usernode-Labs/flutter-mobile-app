Verify a design system widget meets all quality criteria.

## Verifiable Criteria

For each widget in `lib/design_system/src/`, check and report pass/fail:

1. **Format**: Use `dart_format` MCP tool on the widget file — clean
2. **Analyze**: Use `analyze_files` MCP tool — no issues in the widget file
3. **Tests**: Use `run_tests` MCP tool on the widget's test file — passes
4. **No hardcoded values**: No literal numbers for colors, spacing, radius, elevation, opacity, sizing, or animation durations. All must come from ThemeExtension tokens or colorScheme/textTheme.
5. **No banned widgets**: No Material widgets (ElevatedButton, Card, ListTile, Scaffold, AppBar, etc.) or Cupertino widgets. Exceptions: Text, Icon, InkWell, DefaultTextStyle, composing lib/core/widgets/.
6. **Exported**: Widget is exported from `lib/design_system/design_system.dart`
7. **Golden screenshot**: `test/design_system/goldens/<widget_name>.png` must exist. Golden test passes when run.
8. **Genesis document & visual review**:
   - `lib/design_system/.specs/<WidgetName>.genesis.md` must exist
   - Must have an Inspiration section with source identified
   - Must have a Design Decisions section (can note "No deviations — exact token matches" if applicable)
   - Read the Figma reference PNG (`lib/design_system/.specs/<WidgetName>.reference.png`) and the golden PNG (`test/design_system/goldens/<widget_name>.png`) using Claude multimodal
   - Visually compare: do the documented decisions account for the visible differences?
   - If there are significant structural differences not documented in the genesis, flag them

If no spec YAML exists for the widget, checks 7-8 are skipped (backward compatibility with widgets created before this pipeline).

## Output

Report each criterion as PASS or FAIL with details for failures.

Target: $ARGUMENTS (widget name or "all" for all widgets in src/)
