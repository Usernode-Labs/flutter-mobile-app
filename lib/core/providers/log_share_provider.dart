import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
/// On [start] the whole currently-buffered set is sent immediately, then only
/// newly-captured entries are flushed every [flushInterval]. Sending is
/// fire-and-forget: failures keep the cursor put so nothing is lost, and the
/// loop never throws into the UI.
class LogShareController extends StateNotifier<LogShareState> {
  LogShareController({
    required this.ref,
    LogShareService? service,
    HttpDebugLogStore? store,
  })  : _service = service ??
            LogShareService(
              tokenProvider: () => ref.read(authTokenStoreProvider).read(),
            ),
        _store = store ?? HttpDebugLogStore.instance,
        super(const LogShareState());

  final Ref ref;
  final LogShareService _service;
  final HttpDebugLogStore _store;

  static const flushInterval = Duration(seconds: 30);

  Timer? _timer;
  bool _flushing = false;

  /// Cursor into [HttpDebugLogStore.totalAdded]: entries before it were sent.
  int _cursor = 0;
  int? _participantId;
  String _appVersion = 'unknown';
  late final String _platform = _resolvePlatform();

  /// Begin a sharing session for [participantId]. No-op if already sharing.
  Future<void> start(int participantId) async {
    if (state.isSharing) return;
    _participantId = participantId;
    _cursor = 0; // send everything currently buffered on the first flush
    _appVersion = await _resolveAppVersion();
    state = const LogShareState(status: LogShareStatus.sharing);

    await _flush();
    // The first flush may have been told to stop; only arm the timer if not.
    if (mounted && state.isSharing) {
      _timer = Timer.periodic(flushInterval, (_) => _flush());
    }
  }

  /// User-initiated stop. Returns to idle without the [stoppedByServer] flag.
  void stop() {
    _stopTimer();
    state = const LogShareState();
  }

  Future<void> _flush() async {
    if (_flushing) return; // a slow POST is still in flight; skip this tick
    final participantId = _participantId;
    if (participantId == null) return;

    final batch = _store.entriesAdded(_cursor);
    if (batch.isEmpty) return;
    final nextCursor = _store.totalAdded;

    // Honour the viewer's active URL filter so sharing sends exactly what the
    // user sees. Non-matching entries in this range are skipped permanently —
    // the cursor still advances past them so the single-cursor model stays
    // valid (broadening the filter later won't back-fill older entries).
    final query = ref.read(httpLogFilterProvider).trim().toLowerCase();
    final toSend = query.isEmpty
        ? batch
        : batch
            .where((e) => e.url.toLowerCase().contains(query))
            .toList(growable: false);
    if (toSend.isEmpty) {
      _cursor = nextCursor;
      return;
    }

    _flushing = true;
    try {
      final outcome = await _service.postLogs(
        body: _buildBody(toSend),
      );
      if (!mounted) return;
      switch (outcome) {
        case LogShareOutcome.keepGoing:
          _cursor = nextCursor;
        case LogShareOutcome.stop:
          _cursor = nextCursor;
          _stopTimer();
          state = const LogShareState(stoppedByServer: true);
        case LogShareOutcome.failed:
          break; // keep cursor; the same batch retries on the next flush
      }
    } finally {
      _flushing = false;
    }
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

  @override
  void dispose() {
    _stopTimer();
    _service.dispose();
    super.dispose();
  }
}

final logShareControllerProvider =
    StateNotifierProvider<LogShareController, LogShareState>(
  (ref) => LogShareController(ref: ref),
);

/// Case-insensitive URL substring that filters the HTTP debug log viewer.
///
/// Empty means "no filter". Held here (rather than as screen-local state) so
/// the on-screen list, the copy action, and [LogShareController] sharing all
/// honour the same filter.
final httpLogFilterProvider = StateProvider<String>((ref) => '');
