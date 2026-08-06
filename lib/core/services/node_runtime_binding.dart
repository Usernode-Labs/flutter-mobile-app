import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/identity/block_production_store.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

typedef NodeRuntimeConfiguration = ({
  String network,
  String seedlistUrl,
  String genesisUrl,
  bool viewOnly,
  bool enableRealProver,
  String observabilityHubBaseUrl,
  String operatingSystem,
});

extension NodeRuntimeConfigurationValues on NodeRuntimeConfiguration {
  bool get supportsBlockProduction => operatingSystem != 'ios' && !viewOnly;

  String get fingerprint => _stableFingerprint(<Object?>[
        network,
        seedlistUrl,
        genesisUrl,
        viewOnly,
        enableRealProver,
        observabilityHubBaseUrl,
        operatingSystem,
      ]);
}

/// The immutable inputs fixed when a node runtime is constructed.
///
/// This deliberately excludes operational state such as platform intent,
/// sleep, and the desired-state revision. Those values can change without
/// changing the account, signer, producer authority, or chain configuration
/// captured by the running runtime.
typedef NodeRuntimeBinding = ({
  IdentityPhase identityPhase,
  int? participantId,
  String? accountId,
  String? address,
  int? provisionedSeasonId,
  bool blockProductionReleased,
  NodeRuntimeConfiguration configuration,
});

extension NodeRuntimeBindingValues on NodeRuntimeBinding {
  bool get runsViewOnly =>
      configuration.viewOnly || identityPhase == IdentityPhase.guest;

  /// Whether this runtime may own Android block-production recovery support.
  ///
  /// iOS deliberately runs without block production, and view-only builds
  /// never materialize a producer key even when the platform release bit is
  /// true.
  bool get productionEligible =>
      identityPhase == IdentityPhase.ready &&
      blockProductionReleased &&
      configuration.supportsBlockProduction;

  /// Non-secret durable key used to invalidate native recovery work when any
  /// builder-affecting identity or configuration input changes.
  ///
  String get recoveryFingerprint => _stableFingerprint(<Object?>[
        identityPhase.name,
        participantId,
        accountId,
        address,
        provisionedSeasonId,
        blockProductionReleased,
        configuration.fingerprint,
      ]);

  bool matchesIdentity(Identity identity) =>
      identity.phase == identityPhase &&
      identity.participantId == participantId &&
      identity.accountId == accountId &&
      identity.address == address &&
      identity.provisionedSeasonId == provisionedSeasonId;
}

/// Resolves the exact builder inputs for [expected].
///
/// The identity is revalidated after every asynchronous read. A caller must
/// discard `null`: either the identity is not ready, its binding is incomplete,
/// or it was superseded while the binding was being assembled.
Future<NodeRuntimeBinding?> resolveNodeRuntimeBinding(Identity expected) async {
  final participantId = expected.participantId;
  final accountId = expected.accountId;
  final address = expected.address;
  final authenticated = expected.phase == IdentityPhase.ready;
  final localOnly = expected.phase == IdentityPhase.unauthenticated;
  final guest = expected.phase == IdentityPhase.guest;
  if (!authenticated && !localOnly && !guest) {
    return null;
  }
  if (authenticated &&
      (participantId == null ||
          accountId == null ||
          address == null ||
          address.isEmpty)) {
    return null;
  }
  final hasLocalAccount =
      accountId != null && address != null && address.isNotEmpty;
  if (localOnly && !hasLocalAccount && !AppConfig.viewOnly) {
    return null;
  }

  final network = await NetworkPrefs.getNetwork();
  if (!IdentitySnapshots.current.sameScopeAs(expected)) return null;

  final (seedlistUrl, genesisUrl) = switch (network) {
    'internal' => (
        AppConfig.internalSeedlistUrl,
        AppConfig.internalGenesisUrl,
      ),
    'custom' => (
        AppConfig.customSeedlistUrl,
        AppConfig.customGenesisUrl,
      ),
    _ => (
        AppConfig.testnetSeedlistUrl,
        AppConfig.testnetGenesisUrl,
      ),
  };
  final released = hasLocalAccount
      ? await loadBlockProductionReleasedInBucket(
          bucket: NetworkPrefs.bucketForAddress(address),
          network: network,
        )
      : false;
  if (!IdentitySnapshots.current.sameScopeAs(expected)) return null;

  final NodeRuntimeConfiguration configuration = (
    network: network,
    seedlistUrl: seedlistUrl,
    genesisUrl: genesisUrl,
    viewOnly: AppConfig.viewOnly,
    enableRealProver: AppConfig.enableRealProver,
    observabilityHubBaseUrl: AppConfig.observabilityHubBaseUrl,
    operatingSystem: Platform.operatingSystem,
  );

  return (
    identityPhase: expected.phase,
    participantId: participantId,
    accountId: accountId,
    address: address,
    provisionedSeasonId: expected.provisionedSeasonId,
    blockProductionReleased: released,
    configuration: configuration,
  );
}

String _stableFingerprint(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();
