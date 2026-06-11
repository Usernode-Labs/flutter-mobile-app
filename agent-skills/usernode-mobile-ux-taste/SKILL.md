---
name: usernode-mobile-ux-taste
description: Apply Usernode mobile UX judgment before building or reviewing screens/widgets. Use for pattern decisions, one-handed crypto flows, trust friction, CTA placement, sheets, modals, nav, and hard-ban audits.
---

# Usernode Mobile UX Taste

This is the "which pattern" layer. `SCREEN_PATTERNS.md` and `LAYOUT.md` explain how to implement the chosen pattern.

## Pattern Decision

Before code, write a `pattern_decision` block:

- operating mode: quick check, setup, transaction, recovery, diagnostics, or exploration;
- session shape: glance, step-by-step, interruptible, high-focus;
- trust level: normal, elevated, or high trust friction;
- device context: one-handed mobile first, small-screen safe;
- chosen pattern: root tab, pushed detail, PSL page, sheet, dialog, wizard, inline state;
- CTA placement and escape route;
- rejected alternatives with one-line reasons.

## Usernode Defaults

- Transaction, wallet, recovery, identity, and permission flows have high trust friction.
- Bottom nav roots should stay predictable and scannable.
- Sheets are for bounded, reversible choices; pushed pages are for complex or high-trust work.
- Primary CTAs should sit where thumbs can reach them and remain visible with keyboard/insets.
- Prefer existing M3 and DS patterns. New patterns need explicit human approval.

## Hard Bans

- Tap targets under 48dp for interactive controls.
- Keyboard-covered primary CTAs.
- Content or actions hidden under status/home indicators.
- Gesture-only controls without a visible affordance and semantic label.
- Icon-only navigation without label/tooltip.
- Sheets or modals with no obvious escape route.
- New visual patterns created from a screenshot/Figma/text brief without M3/existing-DS gap proof.

## Text-Only Input

Ask the user for a sketch, screenshot, or Figma reference first. If they explicitly override and ask to proceed text-only, record the uncertainty in `pattern_decision.uncertainty`.
