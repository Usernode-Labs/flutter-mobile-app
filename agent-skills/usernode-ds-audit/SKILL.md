---
name: usernode-ds-audit
description: Audit Usernode design-system widgets, screens, or PR changes. Use for verify-widget, screen-audit, PR audit, DS compliance, and mobile UX hard-ban review.
---

# Usernode DS Audit

Route DS quality checks by scope.

## Scopes

- Widget:

  ```bash
  bash tool/verify-widget.sh <WidgetName>
  ```

- All public DS exports:

  ```bash
  bash tool/verify-widget.sh --all
  ```

- Screen:

  ```bash
  bash tool/screen-audit.sh <path/to/screen.dart>
  ```

- PR/current branch:

  ```bash
  git diff --name-only origin/develop...HEAD
  ```

  Route changed `lib/design_system/src/*.dart` files to widget verification and changed screen/page files to screen audit.

## Review-Side Taste Gate

For screen and PR scopes, explicitly check the `usernode-mobile-ux-taste` hard bans:

- interactive tap targets are at least 48dp;
- primary CTAs are not covered by the keyboard;
- safe areas and home indicator clearance are respected;
- no gesture-only affordances without visible/semantic cues;
- navigation icons have labels or tooltips;
- every modal/sheet has an escape route.

Mark static failures as blocking. Mark uncertain cases as manual review warnings with the exact file path and reason.

## Full Quality Gate

Use the repo commands from `AGENTS.md`: format check, analyze, tests, and ds_lints. Keep findings actionable and ordered by severity.
