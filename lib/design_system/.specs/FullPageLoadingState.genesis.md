# FullPageLoadingState — Genesis

## What
A centered `CircularProgressIndicator` for use as the `body:` of a `Scaffold` when the entire screen is loading.

## Why
Multiple screens hand-roll identical `Center(child: CircularProgressIndicator())` patterns with varying `strokeWidth` values. This widget standardizes the loading indicator and provides a single point of change.

## Design Decisions
- **strokeWidth 2.5** — matches the most common existing usage; thinner than M3 default (4.0) for a lighter feel.
- **No configurable props** — intentionally minimal. Screens needing custom loading (skeleton, shimmer) build their own. This covers the 80% case.
- **No Scaffold** — the widget is the body *content*, not a full page. The screen provides the Scaffold and AppBar.

## Figma
No Figma reference — loading indicators are not designed per-screen.
