part of 'package:crypto_mobile_app/main.dart';

/// The private, one-way process boundary used by the hidden network switcher.
///
/// A network change is accepted only from the signed-out projection. Once it
/// is accepted, Dart alarm admission closes synchronously, the current native
/// application incarnation is invalidated, and only the next-launch network
/// preference is changed. No wallet, credential, or per-network data is wiped.
final class _NetworkRestartBoundary extends ChangeNotifier {
  _NetworkRestartBoundary({
    required _NativeSessionRuntime nativeSession,
    required PlatformAlarmService platformAlarms,
  })  : _nativeSession = nativeSession,
        _platformAlarms = platformAlarms;

  final _NativeSessionRuntime _nativeSession;
  final PlatformAlarmService _platformAlarms;
  final _log = LoggingService.instance.withTag('usernode/NetworkRestart');

  bool _active = false;
  String? _committedNetwork;
  Object? _failure;

  bool get active => _active;
  String? get committedNetwork => _committedNetwork;
  Object? get failure => _failure;

  /// Claims the process for a network restart before returning to feature UI.
  ///
  /// False means the request was rejected without changing process state.
  bool request(String network) {
    if (_active) return true;
    if (!NetworkPrefs.isSupportedNetwork(network) ||
        _nativeSession.sessions.current.identity.status !=
            SessionProjectionStatus.signedOut) {
      return false;
    }

    _active = true;
    _platformAlarms.beginProcessRestart();
    notifyListeners();
    unawaited(_commitAndTerminate(network));
    return true;
  }

  Future<void> _commitAndTerminate(String network) async {
    try {
      if (!await _platformAlarms
          .invalidateApplicationIncarnation()
          .timeout(const Duration(seconds: 5))) {
        throw StateError('Could not invalidate the application incarnation');
      }
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(NetworkPrefs.networkKey, network)) {
        throw StateError('Could not persist the selected network');
      }
      _committedNetwork = network;
      notifyListeners();
    } catch (error, stackTrace) {
      _failure = error;
      _log.error(
        'Could not prepare the network restart',
        error: error,
        stackTrace: stackTrace,
      );
      notifyListeners();
      return;
    }

    try {
      await _platformAlarms.terminateForNetworkChange();
    } catch (error, stackTrace) {
      // The next-launch input is already committed and the process is inert.
      // The visible surface instructs the user to relaunch manually.
      _log.error(
        'Could not terminate after committing the network change',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

final class _NetworkRestartSurface extends StatelessWidget {
  const _NetworkRestartSurface({required this.boundary});

  final _NetworkRestartBoundary boundary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final network = boundary.committedNetwork;
    final String message;
    if (boundary.failure != null) {
      message = l10n.networkRestartFailed;
    } else if (network == null) {
      message = l10n.networkRestartPreparing;
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      message = l10n.networkSwitchedRestartIos(network);
    } else {
      message = l10n.networkSwitchedRestartAndroid(network);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (network == null && boundary.failure == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                ],
                Text(
                  l10n.networkRestartRequired,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
