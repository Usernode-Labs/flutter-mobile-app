# ChallengeDetailPage — Genesis

## Inspiration

Figma node `2943:28627` ("Home>ChallengeDetail") — full-page detail view for a blockchain challenge. Shows a large app bar (back arrow, category icon, title, subtitle), blue reward card, description sections (Why, Task, Requirements), and total reward summary card.

## Design Decisions

### Page as CustomScrollView
Uses `CustomScrollView` with `TopAppBar(size: .large)` as first sliver, followed by a `SliverToBoxAdapter` containing the card content. This enables the collapsible app bar behavior.

### Flexible sections list
`List<ChallengeDetailSection>` instead of fixed params. Different challenges may have different sections; the feature screen maps API data to this list. Uses a typedef record `({String title, String body})`.

### Composed rewardCard param
The page takes a `Widget rewardCard` (not exploded params). The caller builds the `ChallengeRewardCard` and passes it in. Cleaner API, independently testable.

### Two separate white cards
Description sections card and total reward card are separate widgets, matching Figma layout. Both are private widgets inside `challenge_detail_page.dart` — not complex enough to extract.

### White card styling
Both `_SectionsCard` and `_TotalRewardCard` use `surfaceContainerLowest` background with `borderRadiusLargeIncreased` (20px). Section headings use `labelLarge`, body text uses `bodySmall` with `onSurfaceVariant`.

### ChallengeCategoryIcon in TopAppBar
The page composes `ChallengeCategoryIcon` internally from the `category` param, passing it to `TopAppBar.image`. This keeps the external API clean — caller only needs to pass the category enum.

## Composition

**Use when:** Full-screen detail view for a single challenge.
**Parent containers:** Pushed via `context.push()` as a standalone route — not inside tabs or IndexedStack.
**Pair with:** `TopAppBar` (large variant with category icon), `ChallengeRewardCard`, `ChallengeCategoryIcon`.
**Anti-patterns:** Don't embed inside another scroll container — it manages its own scrolling.
**Screen example:** `lib/features/challenges/screens/challenge_detail_screen.dart`
