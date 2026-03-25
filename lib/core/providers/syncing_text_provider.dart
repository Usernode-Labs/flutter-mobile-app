import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fallback shown before the first stream emission arrives.
const String kSyncingTextFallback = 'Syncing.';

/// Cycles "Syncing." → "Syncing.." → "Syncing..." every 500ms.
/// Active only while watched; auto-disposes when no listeners.
final syncingTextProvider = StreamProvider.autoDispose<String>((ref) {
  return Stream.periodic(const Duration(milliseconds: 500), (i) {
    final dots = (i % 3) + 1;
    return 'Syncing${'.' * dots}';
  });
});
