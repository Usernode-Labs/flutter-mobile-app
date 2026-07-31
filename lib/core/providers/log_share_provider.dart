import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/services/http_debug_log_store.dart';
import 'package:crypto_mobile_app/core/services/log_share_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

enum LogShareStatus { idle, sharing }

/// State of the "share logs with the team" feature.
///
/// [stoppedByServer] is set for the single transition where the backend asked
/// us to stop (`{"continue": false}` or 404). The UI listens for it to surface
/// a message, then the user is free to start again (the button stays enabled).
class LogShareState {
  const LogShareState({
    this.status = LogShareStatus.idle,
    this.stoppedByServer = false,
  });

  final LogShareStatus status;
  final bool stoppedByServer;

  bool get isSharing => status == LogShareStatus.sharing;
}

/// Drives periodic, incremental sharing of the HTTP debug log buffer.
///
/// On [start] the current participant's whole buffered set is sent immediately,
/// then only their newly-captured entries are flushed every [flushInterval].
/// Foreign and anonymous exchanges are skipped permanently by this session's
/// global cursor. Sending is fire-and-forget: failures keep the cursor put so
/// nothing is lost, and the loop never throws into the UI.
class LogShareController extends StateNotifier<LogShareState> {
  LogShareController({
    required Identity Function() currentIdentity,
    required Future<String?> Function() tokenProvider,
    required String Function() filterProvider,
    LogShareService? service,
    HttpDebugLogStore? store,
  })  : _currentIdentity = currentIdentity,
        _tokenProvider = tokenProvider,
        _filterProvider = filterProvider,
        _service = service ?? LogShareService(),
        _store = store ?? HttpDebugLogStore.instance,
        super(const LogShareState());

  final Identity Function() _currentIdentity;
  final Future<String?> Function() _tokenProvider;
  final String Function() _filterProvider;
  final LogShareService _service;
  final HttpDebugLogStore _store;

  static const flushInterval = Duration(seconds: 30);

  Timer? _timer;
  final Set<_LogShareSessionLease> _flushingLeases = {};
  int _generation = 0;

  /// Cursor into [HttpDebugLogStore.totalAdded]: entries before it were sent.
  int _cursor = 0;
  _LogShareSessionLease? _lease;
  String _appVersion = 'unknown';
  late final String _platform = _resolvePlatform();

  /// Begin a sharing session for [participantId]. No-op if already sharing.
  Future<void> start(int participantId) async {
    if (state.isSharing) return;
    final generation = ++_generation;
    final lease = await _captureLease(participantId);
    if (!mounted || generation != _generation || lease == null) return;
    final appVersion = await _resolveAppVersion();
    if (!mounted ||
        generation != _generation ||
        !await _credentialIsCurrent(lease)) {
      return;
    }

    _lease = lease;
    _cursor = 0; // send everything currently buffered on the first flush
    _appVersion = appVersion;
    state = const LogShareState(status: LogShareStatus.sharing);

    await _flush();
    // The first flush may have been told to stop; only arm the timer if not.
    if (mounted &&
        generation == _generation &&
        identical(_lease, lease) &&
        state.isSharing) {
      _stopTimer();
      _timer = Timer.periodic(flushInterval, (_) => _flush());
    }
  }

  /// User-initiated stop. Returns to idle without the [stoppedByServer] flag.
  void stop() {
    _generation++;
    _lease = null;
    _stopTimer();
    if (mounted) state = const LogShareState();
  }

  void identityChanged(Identity identity) {
    final lease = _lease;
    if (lease != null && !lease.identity.sameScopeAs(identity)) stop();
  }

  Future<void> _flush() async {
    final lease = _lease;
    if (lease == null || !_activeIdentityIsCurrent(lease)) return;
    // Coalesce ticks only within one sharing lease. A replacement identity is
    // allowed to flush immediately while the superseded lease's transport is
    // still completing; each finalizer removes only its own lease.
    if (_flushingLeases.contains(lease)) return;

    final nextCursor = _store.totalAdded;
    if (nextCursor == _cursor) return;
    final batch = _store.entriesAddedForOwner(_cursor, lease.owner);
    if (batch.isEmpty) {
      // Foreign and anonymous rows still occupy positions in the global
      // cursor. Advance past them only while this exact credential remains
      // current; a stale session must not mutate its replacement's cursor.
      if (await _activeCredentialIsCurrent(lease)) {
        _cursor = nextCursor;
      } else {
        _stopStaleLease(lease);
      }
      return;
    }

    // Honour the viewer's active URL filter within this owner's rows.
    // Non-matching entries in this range are skipped permanently — the cursor
    // still advances past them so the single-cursor model stays valid
    // (broadening the filter later won't back-fill older entries).
    final query = _filterProvider().trim().toLowerCase();
    final toSend = query.isEmpty
        ? batch
        : batch
            .where((e) => e.url.toLowerCase().contains(query))
            .toList(growable: false);
    if (toSend.isEmpty) {
      if (await _activeCredentialIsCurrent(lease)) {
        _cursor = nextCursor;
      } else {
        _stopStaleLease(lease);
      }
      return;
    }

    _flushingLeases.add(lease);
    try {
      final outcome = await _service.postLogs(
        body: _buildBody(toSend),
        credential: lease.credential,
        sendIfCredentialCurrent: (_, send) =>
            _sendIfActiveCredentialCurrent(lease, send),
      );
      if (!mounted || !await _activeCredentialIsCurrent(lease)) {
        _stopStaleLease(lease);
        return;
      }
      switch (outcome) {
        case LogShareOutcome.keepGoing:
          _cursor = nextCursor;
        case LogShareOutcome.stop:
          _cursor = nextCursor;
          _stopTimer();
          state = const LogShareState(stoppedByServer: true);
        case LogShareOutcome.failed:
          break; // keep cursor; the same batch retries on the next flush
        case LogShareOutcome.stale:
          _stopStaleLease(lease);
      }
    } finally {
      _flushingLeases.remove(lease);
    }
  }

  Future<_LogShareSessionLease?> _captureLease(int participantId) async {
    final identity = _currentIdentity();
    if (!identity.isAuthenticated || identity.participantId != participantId) {
      return null;
    }
    String? token;
    try {
      token = await _tokenProvider();
    } catch (_) {
      return null;
    }
    if (token == null ||
        token.isEmpty ||
        !identity.sameScopeAs(_currentIdentity())) {
      return null;
    }
    return _LogShareSessionLease(
      identity: identity,
      owner: AuthenticatedUserScope(participantId: participantId),
      credential: AuthCredentialLease(epoch: identity.epoch, token: token),
    );
  }

  bool _activeIdentityIsCurrent(_LogShareSessionLease lease) =>
      identical(_lease, lease) &&
      lease.identity.sameScopeAs(_currentIdentity());

  Future<bool> _credentialIsCurrent(_LogShareSessionLease lease) async {
    if (!lease.identity.sameScopeAs(_currentIdentity())) return false;
    try {
      final token = await _tokenProvider();
      return lease.identity.sameScopeAs(_currentIdentity()) &&
          token == lease.credential.token;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _activeCredentialIsCurrent(
    _LogShareSessionLease lease,
  ) async {
    if (!_activeIdentityIsCurrent(lease)) return false;
    final current = await _credentialIsCurrent(lease);
    return current && _activeIdentityIsCurrent(lease);
  }

  Future<http.Response?> _sendIfActiveCredentialCurrent(
    _LogShareSessionLease lease,
    Future<http.Response> Function() send,
  ) async {
    if (!_activeIdentityIsCurrent(lease)) return null;
    String? token;
    try {
      token = await _tokenProvider();
    } catch (_) {
      return null;
    }
    if (!_activeIdentityIsCurrent(lease) || token != lease.credential.token) {
      return null;
    }
    // Start the request in the same continuation as the final lease check.
    return send();
  }

  void _stopStaleLease(_LogShareSessionLease lease) {
    if (identical(_lease, lease)) stop();
  }

  Map<String, dynamic> _buildBody(List<HttpLogEntry> batch) => {
        'logged_at': DateTime.now().toUtc().toIso8601String(),
        'level': 'info',
        'message': 'http debug logs',
        'app_version': _appVersion,
        'platform': _platform,
        'context': const <String, dynamic>{},
        'events': batch.map((e) => e.toJsonEvent()).toList(growable: false),
      };

  Future<String> _resolveAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  String _resolvePlatform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return Platform.operatingSystem;
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @visibleForTesting
  int get debugCursor => _cursor;

  @visibleForTesting
  Future<void> debugFlush() => _flush();

  @override
  void dispose() {
    _stopTimer();
    _service.dispose();
    super.dispose();
  }
}

final logShareControllerProvider =
    StateNotifierProvider<LogShareController, LogShareState>(
  (ref) {
    final controller = LogShareController(
      currentIdentity: () => ref.read(identityProvider),
      tokenProvider: () => ref.read(authTokenStoreProvider).read(),
      filterProvider: () => ref.read(httpLogFilterProvider),
    );
    ref.listen<Identity>(
      identityProvider,
      (_, next) => controller.identityChanged(next),
    );
    return controller;
  },
);

class _LogShareSessionLease {
  const _LogShareSessionLease({
    required this.identity,
    required this.owner,
    required this.credential,
  });

  final Identity identity;
  final AuthenticatedUserScope owner;
  final AuthCredentialLease credential;
}

/// Case-insensitive URL substring that filters the HTTP debug log viewer.
///
/// Empty means "no filter". Held here (rather than as screen-local state) so
/// the on-screen list, the copy action, and [LogShareController] sharing all
/// honour the same filter.
final httpLogFilterProvider = StateProvider<String>((ref) => '');
