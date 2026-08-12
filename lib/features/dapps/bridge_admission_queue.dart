import 'dart:async';

/// Serializes the short admission phase of overlapping bridge requests.
///
/// Request handlers run after [run] returns and remain concurrent. Only the
/// security/session decision is ordered, so a session-handoff fence closes
/// before any later wallet request can overtake it.
final class BridgeAdmissionQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() admit) async {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    await previous;
    try {
      return await admit();
    } finally {
      release.complete();
    }
  }
}
