/// Processes a list of items in chunks, yielding to the event loop between
/// chunks so the UI thread can render frames.
///
/// Use this to wrap synchronous FFI calls (e.g. `utxoToJson`) that cannot be
/// moved to an isolate because they operate on FRB opaque types.
Future<List<R>> processInChunks<T, R>(
  List<T> items,
  R Function(T) transform, {
  int chunkSize = 20,
}) async {
  final results = <R>[];
  for (var i = 0; i < items.length; i++) {
    results.add(transform(items[i]));
    if (i % chunkSize == 0 && i > 0) {
      // Yield to the event loop so pending UI frames can be served.
      await Future<void>.delayed(Duration.zero);
    }
  }
  return results;
}
