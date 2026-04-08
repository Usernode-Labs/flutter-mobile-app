# FullPageErrorState — Genesis

## What
A centered error display with icon, message, optional detail, and optional retry button. Designed for the `body:` of a `Scaffold` when data loading has failed.

## Why
4+ screens hand-roll error states with inconsistent layouts: some use Column + Text + Button, others just show a placeholder dash. This widget codifies the error pattern with consistent spacing, icon, and optional retry.

## Design Decisions
- **Layout mirrors EmptyState** — same Center → Padding → Column structure with horizontal `space24` padding, `mainAxisSize: min`.
- **`Symbols.error_sharp` icon** — consistent with the project's Material Symbols Sharp convention. Fixed at 48px, colored `onSurfaceVariant` (muted, not alarming).
- **`FilledButton` for retry** — prominent primary action. The `retryLabel` defaults to "Retry" but is customizable for l10n.
- **No Scaffold** — like FullPageLoadingState, this is body content, not a full page.
- **`detail` is optional** — many error states don't need technical detail. When provided, it appears below the message in `bodyMedium` / `onSurfaceVariant`.

## Figma
No dedicated Figma reference — error states follow the app's general layout patterns.

## Composition

**Use when:** An async operation fails and the entire screen area should show the error with a retry option.
**Parent containers:** `Scaffold` body, PSL `surfaceSlivers` (via `SliverFillRemaining`), or `TabBarView` child.
**Pair with:** Provider error states — wrap in `AsyncValue.when(error: ...)` pattern.
**Anti-patterns:** Don't use for inline errors within a list — use a smaller error indicator. Don't add a Scaffold — this is body content only.
