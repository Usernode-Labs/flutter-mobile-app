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
/// stops a producing node on logout/demotion, and — because the mode is decided
/// inside `startNode` — anything that restarts it brings it back keyless.
///
/// **The residual gap is cross-engine and needs Rust.** Android runs a second
/// Flutter engine for background alarms (`BackgroundAlarmEngine`). The two
/// engines share only storage, with no cross-engine lock, so a logout completing
/// in the UI engine during the sub-second window in which the alarm engine is
/// building a keyed node cannot be observed in time: the alarm engine may
/// publish a producing node for a user who just signed out. Closing this fully
/// requires a capability the Dart layer does not have — a graceful, awaitable
/// node shutdown and/or single-owner production gate in `usernode`, so a node's
/// producing state can be changed (or refused) on a live node rather than only
/// fixed at build. Tracked as the node-lifecycle work.
NodeMode resolveNodeMode({
  required bool hasSessionToken,
  required bool hasOnchainAccount,
  required UserLevel? cachedLevel,
}) {
  final keyed =
      hasSessionToken && hasOnchainAccount && cachedLevel == UserLevel.operator;
  return keyed ? NodeMode.keyed : NodeMode.keyless;
}
