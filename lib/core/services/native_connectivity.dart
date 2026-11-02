import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:connectivity_plus/connectivity_plus.dart'
    show ConnectivityResult;

/// The phone's own view of its network: which links are up, as
/// `connectivity_plus` reports them.
///
/// It says nothing about whether a request will get through (a network that
/// passes no packets still reads as `wifi`), only whether there is a link at
/// all. Read through [nativeConnectivityProvider], so a test can hand the
/// screens that use it a fake instead of the plugin's platform channels.
abstract interface class NativeConnectivity {
  /// Every change the platform reports.
  Stream<List<ConnectivityResult>> get changes;

  /// The links up now.
  Future<List<ConnectivityResult>> check();
}

/// [NativeConnectivity] from the `connectivity_plus` plugin.
final class PluginNativeConnectivity implements NativeConnectivity {
  const PluginNativeConnectivity();

  @override
  Stream<List<ConnectivityResult>> get changes =>
      Connectivity().onConnectivityChanged;

  @override
  Future<List<ConnectivityResult>> check() =>
      Connectivity().checkConnectivity();
}

final nativeConnectivityProvider = Provider<NativeConnectivity>(
  (ref) => const PluginNativeConnectivity(),
);

/// One reading of [NativeConnectivity], in the shape the web page is sent.
@immutable
final class ConnectivitySnapshot {
  /// [ConnectivityResult.name]s in the order given, each once.
  ConnectivitySnapshot.of(Iterable<ConnectivityResult> results)
      : via = List.unmodifiable({for (final result in results) result.name});

  final List<String> via;

  /// False when nothing is up: an empty reading, or only `none`.
  bool get online => via.any((name) => name != ConnectivityResult.none.name);

  Map<String, Object> toJson() => {'online': online, 'via': via};

  @override
  bool operator ==(Object other) =>
      other is ConnectivitySnapshot && listEquals(other.via, via);

  @override
  int get hashCode => Object.hashAll(via);

  @override
  String toString() => 'ConnectivitySnapshot($via)';
}
