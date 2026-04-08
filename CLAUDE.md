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

## Planning & Approach

- Prefer lean/minimal approaches. Start with the simplest viable solution and iterate.
- Do NOT over-specify plans. Keep plans under 200 words with numbered steps unless complexity demands more.
- Before committing to a multi-step implementation, do a quick feasibility check (environment, dependencies, platform constraints).

## MCP Servers

Figma and Dart MCP servers are configured at local scope (not in .mcp.json).
If MCP tools fail, do NOT debug .mcp.json — servers are in ~/.claude.json.
Re-add via: `claude mcp add --transport http <name> <url>`
Never add a "type" field to .mcp.json — schema validation rejects it.

## Git Workflow

- Before stashing or switching branches with staged changes, commit current work first or confirm with user.
- When pre-commit hooks fail on issues unrelated to current changes, diagnose once. If the failure is environmental (missing node_modules, unrelated lint), use --no-verify and note it.
- **Pre-commit hook**: `.githooks/pre-commit` runs `dart format --set-exit-if-changed` then `flutter analyze` on staged `.dart` files. Activate with `git config core.hooksPath .githooks`.
- **Format-and-analyze rule (Claude)**: After modifying any `.dart` file, run `dart format` and `flutter analyze` on the changed files before considering the task done.

## Design System Boundary

All new design system work lives in `lib/design_system/`. Existing code is untouched.

- **M3-first rule (TOP PRIORITY)**: Never create a custom widget that duplicates an M3 component (ListTile, Card, Switch, Checkbox, etc.). Use M3 directly and compose DS *slot widgets* (IconBadge, StatusBadge, etc.) into M3 containers. Only create a custom widget when M3 genuinely doesn't cover the pattern — prove the gap first.
- **New widgets**: When M3 doesn't cover the need, build from core primitives with M3 alignment in mind.
- **Composing existing `lib/core/widgets/`** (AppButton, AppCard, etc.) is allowed.
- **Tokens**: Access via `Theme.of(context).extension<T>()!` (e.g., `AppSpacing`, `AppRadii`, `AppElevation`)
- **Colors**: `Theme.of(context).colorScheme` — **all structural roles are achromatic grey** (primary, secondary, tertiary, containers). Only `error*` has hue. To introduce chromatic color, use `Theme.of(context).extension<AppSemanticColors>()!` (technical/flash/community/success/warning). Never assume a `ColorScheme` role carries color.
- **Typography**: `Theme.of(context).textTheme`
- **Presentation-only**: Design system widgets take all state via constructor params (data + callbacks). No providers, no `ConsumerWidget`, no services. No FRB-generated types in constructor params (they transitively import native FFI). Screens in `lib/features/` wire state to widgets.
- **Widgetbook rule**: Every new design system widget gets a use case that imports the **real widget** with mock data via knobs — never hand-built replicas.
- **Quality gate**: `dart format` clean, `flutter analyze` passes, tests pass, `ds_lints` clean (no warnings)
- **Screen building**: `lib/design_system/docs/SCREEN_PATTERNS.md` — templates, token reference, checklists
- **Widget pipeline**: `.claude/commands/widget-from-figma.md` → `.claude/commands/figma-inspect.md` → `.claude/commands/verify-widget.md`
- **Build constraints**: `lib/design_system/.specs/BUILD_INSTRUCTIONS.md` — canonical token-to-code reference
- **All constraints**: `lib/design_system/docs/CONSTRAINTS.md` — rules, lint rules, quality gate

## Maturity Matrix

The project tracks mainnet readiness via 12 initiative tracker issues (labeled `type:tracker`). Every issue, PR, and discussion must connect to an initiative. See [Discussion #370](https://github.com/Usernode-Labs/flutter-mobile-app/discussions/370) for the full plan.

### When creating an issue:
1. Apply the matching `init:*` label (ask the user which initiative if unclear)
2. Add `Relates to #N` in the body (where N = the tracker issue number for that initiative)
3. After creation, update the tracker issue body — add the new issue to the appropriate phase tasklist as an unchecked `- [ ] #M description` item

### When creating a PR:
1. Apply the matching `init:*` label
2. Include `Relates to #N` referencing the tracker issue
3. If the PR closes an issue, use `Closes #M` — the tracker tasklist updates when the issue closes

### When closing an issue:
1. Check if the issue is referenced in a tracker tasklist (`gh issue view <tracker> --json body`)
2. If all items in a phase section are now closed, suggest updating the phase marker from 🔄 to ✅

### Initiative labels:
`init:bg-node`, `init:app-stores`, `init:zk-identity`, `init:fair-rewards`, `init:mini-apps`, `init:block-explorer`, `init:wallet`, `init:bridge`, `init:dex`, `init:design-system`, `init:leaderboard`, `init:landing-page`
