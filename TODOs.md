# TODOs

## Design System

- **Extract `ShimmerCardSkeleton` DS widget** — `_ChallengeCardShimmer` in `challenges_screen.dart` and the "Card Skeleton" widgetbook use case in `shimmer_use_case.dart` are copy-pasted duplicates. Extract into `lib/design_system/src/shimmer_card_skeleton.dart`, export from barrel, and have both locations import the real widget.

- **Extract `'IBMPlexMono'` into a constant** — The string literal `'IBMPlexMono'` is hardcoded 16+ times across 9 files. Define a constant (e.g., `kMonoFontFamily`) in a design system token file and replace all occurrences.
