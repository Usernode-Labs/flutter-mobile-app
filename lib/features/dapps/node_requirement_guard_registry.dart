import 'dart:convert';
import 'dart:math';

import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';

typedef NodeRequirementGuardIdFactory = String Function();

/// Owns page-requested awake leases for one WebView.
///
/// Guard IDs are opaque, realm-bound, scope-bound and exact-use. Registry
/// cleanup is synchronous with respect to ownership: a lease acquisition that
/// finishes after its realm was retired is immediately released and is never
/// published as a live guard.
final class NodeRequirementGuardRegistry {
  NodeRequirementGuardRegistry({NodeRequirementGuardIdFactory? guardIdFactory})
      : _guardIdFactory = guardIdFactory ?? _randomGuardId;

  final NodeRequirementGuardIdFactory _guardIdFactory;
  final Map<String, _NodeRequirementGuardEntry> _guards = {};
  final Map<String, int> _realmEpochs = {};
  String? _activeRealmMarker;
  bool _acceptingAcquisitions = true;
  bool _disposed = false;

  int get activeCount => _guards.length;

  Future<String?> acquire({
    required String scope,
    required String realmMarker,
    required Future<SessionNodeAwakeLease> Function() acquireLease,
  }) async {
    if (_disposed ||
        !_acceptingAcquisitions ||
        (_activeRealmMarker != null && _activeRealmMarker != realmMarker)) {
      return null;
    }
    final epoch = _realmEpochs.putIfAbsent(realmMarker, () => 0);
    final lease = await acquireLease();
    if (_disposed ||
        _realmEpochs[realmMarker] != epoch ||
        (_activeRealmMarker != null && _activeRealmMarker != realmMarker)) {
      await lease.release();
      return null;
    }

    String guardId;
    do {
      guardId = _guardIdFactory();
    } while (_guards.containsKey(guardId));
    _guards[guardId] = _NodeRequirementGuardEntry(
      scope: scope,
      realmMarker: realmMarker,
      lease: lease,
    );
    return guardId;
  }

  Future<bool> release({
    required String guardId,
    required String scope,
    required String realmMarker,
  }) async {
    final entry = _guards[guardId];
    if (entry == null ||
        entry.scope != scope ||
        entry.realmMarker != realmMarker) {
      return false;
    }
    _guards.remove(guardId);
    await entry.lease.release();
    return true;
  }

  /// Retires guards created by documents other than [realmMarker].
  Future<void> retainOnlyRealm(String realmMarker) async {
    if (_disposed) return;
    _acceptingAcquisitions = true;
    _activeRealmMarker = realmMarker;
    final retiredRealms = _realmEpochs.keys
        .where((candidate) => candidate != realmMarker)
        .toList(growable: false);
    for (final retired in retiredRealms) {
      _realmEpochs[retired] = (_realmEpochs[retired] ?? 0) + 1;
    }
    final retiredEntries = _guards.entries
        .where((entry) => entry.value.realmMarker != realmMarker)
        .toList(growable: false);
    for (final entry in retiredEntries) {
      _guards.remove(entry.key);
    }
    await Future.wait(
        retiredEntries.map((entry) => entry.value.lease.release()));
  }

  Future<void> releaseAll() async {
    if (_disposed) return;
    _acceptingAcquisitions = false;
    for (final realm in _realmEpochs.keys.toList(growable: false)) {
      _realmEpochs[realm] = (_realmEpochs[realm] ?? 0) + 1;
    }
    final entries = _guards.values.toList(growable: false);
    _guards.clear();
    await Future.wait(entries.map((entry) => entry.lease.release()));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _acceptingAcquisitions = false;
    for (final realm in _realmEpochs.keys.toList(growable: false)) {
      _realmEpochs[realm] = (_realmEpochs[realm] ?? 0) + 1;
    }
    final entries = _guards.values.toList(growable: false);
    _guards.clear();
    await Future.wait(entries.map((entry) => entry.lease.release()));
  }

  static String _randomGuardId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

final class _NodeRequirementGuardEntry {
  const _NodeRequirementGuardEntry({
    required this.scope,
    required this.realmMarker,
    required this.lease,
  });

  final String scope;
  final String realmMarker;
  final SessionNodeAwakeLease lease;
}
