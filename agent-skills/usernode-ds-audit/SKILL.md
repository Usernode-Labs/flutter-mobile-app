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

## Flutter Layout Gate

When a screen, PR, or runtime report mentions layout trouble, classify it by the primary Flutter constraint failure before proposing fixes:

- `Vertical viewport was given unbounded height`: a scrollable is inside an unconstrained vertical parent; prefer constraining with `Expanded`, `Flexible`, or a bounded sliver structure.
- `InputDecorator ... unbounded width`: a `TextField`/`TextFormField` is inside an unconstrained horizontal parent; wrap the field in `Expanded` or `Flexible`.
- `RenderFlex overflowed`: a `Row`, `Column`, or `Flex` child is asking for more space than available; constrain text/content with `Expanded`, `Flexible`, wrapping, or a scrollable pattern from `LAYOUT.md`.
- `Incorrect use of ParentDataWidget`: `Expanded`, `Flexible`, or `Positioned` is not a direct child of its required parent.
- `RenderBox was not laid out`: treat as a cascade; find the earlier constraint violation and fix that instead.

Do not paper over these failures with arbitrary sizes. Prefer `LayoutBuilder`, parent constraints, existing DS layout patterns, and lazy builders for large/unknown lists.

## Accessibility Gate

For screen and PR scopes, include a VGV-style Flutter accessibility pass:

- icon-only controls have `Tooltip` or `Semantics(label:)`;
- images are labeled or marked decorative with `excludeFromSemantics: true`;
- color is not the only differentiator for state, error, or category;
- drag/swipe-only actions have visible non-drag alternatives;
- fixed-height text containers do not clip at larger text scales;
- user-visible async state changes use DS loading/error/empty states and, where appropriate, live-region semantics;
- animations and custom transitions respect `MediaQuery.disableAnimations`.

Use these checks as Usernode rules. Do not import VGV architecture, Bloc defaults, or Claude-specific hooks.

## Full Quality Gate

Use the repo commands from `AGENTS.md`: format check, analyze, tests, and ds_lints. Keep findings actionable and ordered by severity.
