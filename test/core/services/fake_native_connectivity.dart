import 'dart:async';

import 'package:crypto_mobile_app/core/services/native_connectivity.dart';

/// [NativeConnectivity] for widget tests: [check] answers [current], and
/// [emit] reports a change at once.
class FakeNativeConnectivity implements NativeConnectivity {
  FakeNativeConnectivity([this.current = const [ConnectivityResult.wifi]]);

  List<ConnectivityResult> current;

  final _changes = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );

  bool get hasListener => _changes.hasListener;

  @override
  Stream<List<ConnectivityResult>> get changes => _changes.stream;

  @override
  Future<List<ConnectivityResult>> check() async => current;

  void emit(List<ConnectivityResult> results) {
    current = results;
    _changes.add(results);
  }
}
