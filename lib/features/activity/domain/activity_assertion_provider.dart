/// Supplies one short-lived account assertion to the native Activity client.
///
/// The concrete transport is intentionally outside this boundary. A later
/// Social integration may use an exact-origin WebView bridge or an app link,
/// without exposing Activity consumer tokens to that transport.
abstract interface class ActivityAssertionProvider {
  Future<String> acquireAssertion();
}
