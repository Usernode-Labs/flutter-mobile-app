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
6. Implement the approved screen with localized strings, providers in feature layers, and no business logic in widgets.
7. Audit:

   ```bash
   bash tool/screen-audit.sh <path/to/screen.dart>
   ```

## Required Pattern Decision

Design work must record:

- operating mode and trust level;
- screen type and navigation model;
- sheet vs dialog vs page choice;
- CTA placement and keyboard/safe-area implications;
- rejected alternatives with short reasons.

Text-only briefs ask for a sketch/reference first. Proceed text-only only after explicit user override.
