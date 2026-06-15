# Usernode Harness Critical Journeys

Use these critical user journeys when auditing the agent harness against external benchmarks. They are acceptance frames, not a new eval runner.

## 1. Fresh Harness Setup

- Prompt: "Set up this fresh clone for agent work."
- Expected skill route: `usernode-ds-harness-init`.
- Proof: `bash tool/agent-setup.sh` succeeds, `core.hooksPath` is `.githooks`, and repo-local skill adapters exist under ignored `.claude/skills/`, `.agents/skills/`, and `.codex/skills/`.
- Blocking failure: upstream skills are globally installed by default, committed adapter files appear, or frontmatter validation is skipped.

## 2. Text-Only Design Intake

- Prompt: "Build a new DS card from this text description."
- Expected skill route: `usernode-ds-design-intake` then `usernode-mobile-ux-taste`.
- Proof: the agent asks for a sketch, screenshot, or Figma reference before proceeding; if explicitly overridden, the spec records `text_only_override: true` and `pattern_decision.uncertainty`.
- Blocking failure: text-only input silently becomes implementation work or creates a new pattern without M3/existing-DS gap proof.

## 3. DS Widget Build

- Prompt: "Create or revise a design-system widget."
- Expected skill route: `usernode-ds-build-widget`.
- Proof: implementation uses M3/existing DS match-before-make, adds focused test, Widgetbook story under `widgetbook/lib/stories/`, barrel export, genesis doc, catalog row, and passes `bash tool/verify-widget.sh <WidgetName>`.
- Blocking failure: Flutter Widget Previewer replaces Widgetbook, M3 wrappers are added as DS widgets without gap proof, or token/hardcoded-value checks are bypassed.

## 4. DS Screen Audit

- Prompt: "Audit this screen for DS/mobile UX quality."
- Expected skill route: `usernode-ds-audit` with screen scope.
- Proof: `bash tool/screen-audit.sh <path>` runs and the report covers scroll constraints, SafeArea/home-indicator behavior, keyboard-safe CTAs, 48dp targets, gesture semantics, navigation labels, modal escape routes, accessibility labels, text scaling risk, motion reduction, and known Flutter layout-error signatures.
- Blocking failure: audit only checks visual style and misses keyboard, safe-area, gesture-only, or constraint failures.

## 5. PR Review Audit

- Prompt: "Review this PR for DS harness compliance."
- Expected skill route: `usernode-ds-audit` with PR/current-branch scope.
- Proof: changed DS widgets route to `verify-widget`, changed screens route to `screen-audit`, uncertain static findings are called out as manual warnings, and final findings are sorted by severity.
- Blocking failure: review accepts generic external taste over Usernode DS rules, ignores changed Widgetbook/genesis/catalog artifacts, or fails to separate blocking failures from manual-review uncertainty.
