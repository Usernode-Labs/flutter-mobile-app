---
name: usernode-ds-build-screen
description: Build or redesign Usernode Flutter screens using Material 3, existing DS components, and mobile UX taste rules. Use for screen-from-design or redesign-existing-screen work.
---

# Usernode DS Build Screen

Use this for feature screens under `lib/features/` or DS-backed page surfaces.

## Pipeline

1. Determine target mode: `new` or `existing`.
2. Intake: use `usernode-ds-design-intake` for design input.
3. Pattern decision: run `usernode-mobile-ux-taste` before code.
4. Read:
   - `lib/design_system/DESIGN_SYSTEM.md`
   - `lib/design_system/docs/SCREEN_PATTERNS.md`
   - `lib/design_system/docs/LAYOUT.md`
   - `lib/design_system/docs/CONSTRAINTS.md`
5. Match before make:
   - Prefer M3 components directly for containers and controls.
   - Compose existing DS slot widgets.
   - Ask for explicit approval before creating new DS patterns.
6. Responsive and platform fit:
   - Use `LayoutBuilder` or available constraints for adaptive choices; do not branch on hardware type or top-level orientation.
   - Constrain full-width content on large screens instead of letting forms, lists, or text stretch indefinitely.
   - Use lazy builders for long or unknown lists.
   - Respect Android edge-to-edge, IME, and system-bar behavior through existing SafeArea, scaffold, scroll-padding, and `MediaQuery.viewInsets` patterns.
   - Keep primary CTAs reachable, keyboard-safe, and clear of the home indicator.
7. Implement the approved screen with localized strings, providers in feature layers, and no business logic in widgets.
8. Audit:

   ```bash
   bash tool/screen-audit.sh <path/to/screen.dart>
   ```

## Required Pattern Decision

Design work must write a `pattern_decision:` block before implementation. For
new screen specs, store it in `lib/design_system/.specs/<ScreenName>.spec.yaml`.
For existing-screen redesigns where a spec file is not useful, include the same
`pattern_decision:` block in the implementation notes before code changes.

The block must record:

- operating mode and trust level;
- screen type and navigation model;
- sheet vs dialog vs page choice;
- CTA placement and keyboard/safe-area implications;
- rejected alternatives with short reasons.

Text-only briefs ask for a sketch/reference first. Proceed text-only only after explicit user override.
