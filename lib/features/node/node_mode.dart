import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

/// How the node runs.
///
/// - [keyed] loads the active account's secret and configures block production
///   and the wallet signer — the operator path.
/// - [keyless] runs and syncs the chain with no key at all: no block producer,
///   no wallet signer, no mempool autoinsert, no observability intake. Guests
///   and members use it.
enum NodeMode { keyed, keyless }

/// Decides the node mode from local state alone, so it can run before `/me`.
///
/// Keyed requires **all three**: a live session, a local on-chain account, and
/// a cached tier of [UserLevel.operator]. Each guards a distinct failure:
///
/// - **token** — an operator who signed out must stop producing, even though
///   their key is still on the device.
/// - **on-chain account** — no key, nothing to produce with.
/// - **cached operator** — the tier is backend authority (`app:user_type`,
///   written only from a resolved `/me`). A local key is not authority: a
///   demoted or waitlisted member can still hold one, and must not produce.
///
/// Any weaker combination is [keyless]. The bias is deliberate: running keyless
/// when we should be keyed is a recoverable under-privilege, while producing
/// blocks when we should not is not.
///
/// ## What this guarantees, and the one thing it cannot
///
/// **Cold start is exact.** On a fresh process the mode is resolved once from
/// local state and the node is built keyed or keyless accordingly. A guest or
/// member gets a syncing, non-producing node; an operator gets the keyed path.
///
/// **Within a single isolate, session changes are handled.** `startNode`
/// re-resolves the mode as its last `await` and then configures the producer
/// and builds synchronously, so a logout mid-start is caught. `backendLifecycle`
/// stops a producing node on logout/demotion via `stopNode`, which now awaits
/// `NodeControl.shutdown_and_wait` — the run loop has provably exited (block
/// production ceased) before the stop returns. Because the mode is decided
/// inside `startNode`, anything that restarts the node brings it back keyless.
///
/// **The residual gap is a narrow cross-engine race.** Android runs a second
/// Flutter engine for background alarms (`BackgroundAlarmEngine`). The two
/// engines share only storage, with no cross-engine lock, so a logout completing
/// in the UI engine during the sub-second window in which the alarm engine is
/// building a keyed node may not be observed in time. Two `usernode` changes
/// narrow this substantially: `shutdown_and_wait` makes the UI-engine stop
/// deterministic, and `new_inner` now signals the previous global node to shut
/// down when a new one replaces it (best-effort, since a constructor cannot
/// await). Fully closing it — and enabling within-session promotion
/// member→operator without an app restart — needs a live production gate on a
/// running node (toggle/refuse production without rebuilding), which reaches
/// into the VRF/consensus state machine. Tracked as the remaining node-lifecycle
/// work.
NodeMode resolveNodeMode({
  required bool hasSessionToken,
  required bool hasOnchainAccount,
  required UserLevel? cachedLevel,
}) {
  final keyed =
      hasSessionToken && hasOnchainAccount && cachedLevel == UserLevel.operator;
  return keyed ? NodeMode.keyed : NodeMode.keyless;
}
