Verify a design system widget meets all quality criteria.

## Verifiable Criteria

For each widget in `lib/design_system/src/`, check and report pass/fail:

1. **Format**: `dart format --output=none --set-exit-if-changed` on the widget file — clean
2. **Analyze**: `flutter analyze` — no issues in the widget file
3. **Tests**: `flutter test` on the widget's test file — passes
4. **No hardcoded values**: No literal numbers for colors, spacing, radius, elevation, opacity, sizing, or animation durations. All must come from ThemeExtension tokens or colorScheme/textTheme.
5. **No banned widgets**: No Material widgets (ElevatedButton, Card, ListTile, Scaffold, AppBar, etc.) or Cupertino widgets. Exceptions: Text, Icon, InkWell, DefaultTextStyle, composing lib/core/widgets/.
6. **Exported**: Widget is exported from `lib/design_system/design_system.dart`

## Output

Report each criterion as PASS or FAIL with details for failures.

Target: $ARGUMENTS (widget name or "all" for all widgets in src/)
