# Challenge Manual QA Matrix

Use this when manually validating that Flutter responds correctly to the
Leaderboard mobile API. Keep the matrix rooted in what the backend actually
serves, not in hypothetical challenge categories.

The app consumes two contracts:

- `/api/v2/mobile/challenges`: challenge definition and display metadata.
- `/api/v2/mobile/me/breakdown`: participant-specific `challenge_progress`.

Flutter should not infer canonical progress from reasoning prose, old local
mock data, or challenge names. It should render the fields below predictably.

## Backend Fields That Matter

From `/mobile/challenges`:

| Field | Why UI cares |
| --- | --- |
| `id` + `event_id` | Resolves the matching progress row without collisions |
| `goal`, `task`, `description`, `reward` | Card/detail copy and reward ceiling |
| `schedule_start`, `schedule_end` | Deadline bands and availability text |
| `featured`, `featured_order` | Featured band/card treatment |
| `sub_category` | Produce-blocks technical detail treatment |
| `metric.kind`, `metric.label`, `metric.target` | Rail treatment and `current / target` text |
| `cta_*`, `mobile_cta_*`, `source` | Detail CTA destination |

From `/me/breakdown.challenge_progress`:

| Field | Why UI cares |
| --- | --- |
| `challenge_id` | Joins progress to challenge definition |
| `state` | Main UI phase: `none`, `in_progress`, `pending`, `earned`, `missed`, `declined` |
| `current`, `target` | Canonical metric progress |
| `pending_points` | Review/submitted points |
| `earned_points` | Completed/awarded points |
| `description` | Short user-facing helper/status text |

## Primary State Matrix

Create these states from real admin data or from the Widgetbook API matrix. This
is the minimum set that proves the UI reacts to BE-served state correctly.

| BE state/fields | Expected card | Expected detail | Profile completed |
| --- | --- | --- | --- |
| `state=none`, no `current`, no points | Open. State-only challenges show `Not done`; count/sum with target may show `0 / target label`. | Same rail; no invented progress. | Not shown. |
| `state=none`, no metric or binary metric, `pending_points>0` | `Submitted`, `pending N pts`. This is the only mobile-side special case. | Same submitted rail; optional helper from `description`. | Not shown. |
| `state=in_progress`, count/sum, `current < target` | `current / target label`; partial fill; right side shows earned/ceiling or ceiling. | Same rail; helper may explain registered progress. | Not shown. |
| `state=in_progress`, percentage, `current=N` | `N% success`; bounded percentage fill unless produce-blocks. | Same value. Produce-blocks uses the rich technical hero. | Not shown unless backend also marks earned. |
| `state=in_progress`, rank or no bounded metric | Uses short `description` if present, otherwise `In progress`; no fake fill. | Same status/helper. | Not shown. |
| `state=pending`, count/sum, `current < target` | Still in-progress/open based on `current`; do not show submitted just because pending points exist. | Same. Target is not reached yet. | Not shown. |
| `state=pending`, count/sum, `current >= target` | Full rail, `pending N pts`. | Same. | Not shown until `earned`. |
| `state=pending`, missing `current` for count/sum | Do not parse reasoning to make `1 / 3`; render safe state-only/open. | Same; this is a backend data issue to fix. | Not shown. |
| `state=pending`, binary/no metric/rank/percentage | `Submitted` or pending-style rail; `pending N pts` or `waiting review`. | Same. | Not shown. |
| `state=earned` | Completed treatment. Count/sum still shows canonical `current / target` when present; state-only shows `Done`. | Completed rail/helper. | Shown. |
| `state=missed` or `declined` | Never render as completed. If canonical `current / target` exists, it may show progress text without completion styling. | Same; no satisfying completed fill unless BE says `earned`. | Not shown. |

## Field-Shape Checks

These are the real field combinations that have caused bugs. They are more
important than exhaustively inventing one challenge per metric type.

| Case | Setup | Expected result |
| --- | --- | --- |
| Count target | `metric.kind=count`, `metric.label=Actions`, `target=3`, progress `current=1` | `1 / 3 Actions`; one-third fill |
| Count untouched | count target exists, progress `state=none`, `current=null` | `0 / 3 Actions`, not long reasoning text |
| Count pending missing current | `state=pending`, `target=3`, `current=null` | No fabricated `1 / 3`; safe fallback |
| Sum fractional | `metric.kind=sum`, `current=12.5`, `target=100` | Preserve decimal: `12.5 / 100 label` |
| Percentage | `metric.kind=percentage`, `current=62.5` | Percent status/fill; readable decimal/rounded value per mapper |
| Rank | `metric.kind=rank`, `description=Rank 7` | State/prose rendering, no fake bounded fill |
| Unknown metric | unsupported `metric.kind` | Parses as unknown and falls back safely; no crash |
| No metric pending | `metric=null`, `state=none`, `pending_points>0` | Submitted/pending state for form-style challenges |
| Featured | `featured=true`, optional `featured_order` | Appears in Featured band with premium card treatment |
| Produce blocks | `sub_category=PRODUCE_BLOCKS_CHALLENGE` plus event breakdown success/earned data | Technical card/detail, compact and detail rails agree |

## Scope Resolution Checks

These validate that progress comes from the backend shape the app actually
receives.

| Case | Backend shape | Expected result |
| --- | --- | --- |
| Event scope | top-level event `challenge_progress[]` | Matching card/detail use that row |
| Season scope | `season.events[].challenge_progress[]` | Resolve by `(event_id, challenge_id)` |
| Duplicate challenge id | same `challenge_id` under two events | Matching `event_id` wins |
| Missing event id, one match | challenge has `event_id=null`, one progress match exists | Unambiguous fallback succeeds |
| Missing event id, multiple matches | challenge has `event_id=null`, multiple progress matches exist | Return no progress rather than guessing |
| Global shape | `seasons[].events[].challenge_progress[]` | Profile completed history fetches it; scoped challenge pages still use season/event context |

## Manual Device Checklist

For each live challenge you test:

1. Inspect the API row first: challenge definition plus matching progress row.
2. Open Challenges.
3. Confirm band placement: Featured, Today, This week, Season.
4. Confirm card rail:
   - left text matches `state/current/target/description`;
   - right text matches ceiling, pending points, or earned points;
   - fill exists only when backend gives bounded progress;
   - completed cards remain in the stream but read as completed.
5. Open detail.
6. Confirm the detail rail mirrors the source card.
7. Confirm helper text is human-facing and not agent/debug prose.
8. Confirm CTA opens the backend-provided destination.
9. Open Profile completed.
10. Confirm only `earned` challenges appear there.

## Minimum Live Set Before Shipping

Use this reduced set when time is tight:

| Priority | Live scenario | Why |
| --- | --- | --- |
| P0 | Count target below goal, e.g. `1 / 3 Actions` | Proves canonical metric progress and no reasoning parsing |
| P0 | Count target reached but pending | Proves full pending rail before approval |
| P0 | No-metric form submission pending | Proves the one intentional mobile-side pending special case |
| P0 | Earned/completed challenge | Proves card stream + Profile completed |
| P0 | Produce-blocks detail | Proves technical hero uses real event breakdown data |
| P1 | Featured challenge | Proves backend `featured` drives grouping/styling |
| P1 | Missing/ambiguous progress row | Proves safe fallback instead of wrong progress |

## Agent Output Rules That Keep UI Stable

For target-based metrics:

- submit cumulative `metric_current`;
- below target, submit `points=0` unless the challenge intentionally awards
  partial points;
- at target, submit the reward once;
- keep public `description` short and user-facing.

For no-metric/binary submissions:

- use pending points to show that a submission was registered;
- add a duplicate guard so scheduled runs do not compound points.

For every agent:

- put row ids, tx ids, skip reasons, and debug details in run output, not in
  the public progress description.
