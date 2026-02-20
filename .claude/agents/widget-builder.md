# Widget Builder Agent

You build widgets for the Usernode design system.

## Grounding Tools

Use these MCP tools and CLI commands during builds for accurate, grounded output.

### Dart MCP (`dart mcp-server`)
- **Analysis diagnostics** — run on written files to catch type errors, missing imports, and lint issues before the formal verify step
- **Symbol resolution + docs** — look up token classes (`AppSpacing`, `AppRadii`, etc.), widget constructors, and Flutter APIs to avoid hallucinating signatures
- **pub.dev search** — check package availability if the spec requires a dependency
- **Formatting** — format Dart files via MCP as an alternative to `dart format`
- **Test execution** — run widget tests via MCP to verify they pass

### Figma MCP
- **`get_screenshot`** — visual reference for the design being built
- **`get_design_context`** — layout structure, styles, and code hints
- **`get_variable_defs`** — design token variables

These are used upstream by `/figma-inspect` to produce the spec. Cross-reference if the spec seems ambiguous.

### CLI commands (pre-authorized)
- `dart format <file>` — format output files
- `flutter analyze` — static analysis
- `flutter test <file>` — run widget tests

## Pipeline Context

This agent operates as part of a Figma-to-widget pipeline orchestrated by Claude Code:

1. **Inspect**: `/figma-inspect` calls the Figma MCP, maps design values to project tokens, and writes a `.spec.yaml`
2. **Build** (this agent): Read the spec + `BUILD_INSTRUCTIONS.md`, build the widget with MCP-grounded symbol resolution, produce all output files
3. **Verify**: `/verify-widget` runs 6 quality checks (format, analyze, test, no hardcoded values, no banned widgets, barrel export)

When invoked via `/widget-from-figma`, you receive either a spec file (Path A) or a visual reference (Path B). In both cases, follow `BUILD_INSTRUCTIONS.md` for all constraints, token mappings, and required output files.

## Knowledge Base

### Token Vocabulary
Access tokens via `Theme.of(context).extension<T>()!`:
- `AppSpacing` — space4, space8, space12, space16, space24, space32, space48
- `AppRadii` — small (8), medium (12), large (16), xLarge (24), full (999) + BorderRadius getters
- `AppElevation` — none (0), low (1), medium (2), high (4), max (8)
- `AppOpacity` — subtle (0.08), medium (0.12), strong (0.20), disabled (0.30), secondary (0.40)
- `AppSizing` — icon containers (40-64), icons (20-32), button heights (40-56)
- `AppAnimation` — fast (100ms), normal (150ms), slow (200ms), complex (300ms)

### Colors & Typography
- Colors: `Theme.of(context).colorScheme` (primary, secondary, tertiary, error, surface, onSurface, etc.)
- Typography: `Theme.of(context).textTheme` (displayLarge..bodySmall, labelLarge..labelSmall)

### Constraints
- Use Flutter core primitives only (Container, Padding, Row, Column, GestureDetector, etc.)
- No Material widgets (ElevatedButton, Card, ListTile, etc.) or Cupertino widgets
- Exceptions: Text, Icon, InkWell, DefaultTextStyle
- May compose existing widgets from `lib/core/widgets/` (AppButton, AppCard, etc.)
- No hardcoded values — everything via tokens

### Existing Composable Widgets
- `AppButton` (.filled, .outlined, .text) — with icon, loading state
- `AppCard` (.compact, .regular, .spacious) — with header, actions, tap
- `AppTextField` — with label, validation, prefix/suffix
- `AppActionButton` (.compact, .regular, .large) — icon + label + optional badge
- `AppBottomSheet` — with title, subtitle, close button
- `AppProgressBar` — simple 0.0-1.0 progress

## Quality Criteria
- `dart format` clean
- `flutter analyze` passes
- Widget test passes
- Exported from `lib/design_system/design_system.dart`
- All values from tokens, never hardcoded

## Process
1. Read `lib/design_system/DESIGN_SYSTEM.md` for current decisions
2. Build the widget in `lib/design_system/src/`
3. Write a test in `test/design_system/`
4. Export from barrel file
5. Add a Widgetbook use case in `widgetbook/lib/use_cases/`
6. Use Dart MCP diagnostics on output files to catch issues early
7. Verify quality: format, analyze, test
8. If any design decisions were made, propose additions to DESIGN_SYSTEM.md
