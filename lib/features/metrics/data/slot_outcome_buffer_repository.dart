import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/metrics/models/slot_outcome_report.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = LoggingService.instance.withTag('usernode/SlotOutcomeBuffer');

/// Persistent buffer of [SlotOutcomeReport]s queued for the next metrics POST.
///
/// **Why this exists**: a slot reaches its terminal outcome (produced /
/// monitoring timeout) at an arbitrary moment that may not align with a
/// metrics POST. We snapshot at terminal time (so `app_state`, network, etc.
/// reflect the slot window), persist, and ship piggybacked on the next POST.
/// Persistence also lets us survive an app restart between snapshot and POST.
///
/// **Storage**: a single network-prefixed SharedPreferences string holding a
/// JSON array of reports (same pattern as [SlotProductionRepository]).
///
/// **Lifecycle**: append on terminal outcome, drain at POST time, discard
/// successfully-shipped ids. Failed POSTs leave the buffer intact so the next
/// tick retries.
///
/// **Bound**: keeps the most recent [_maxBufferSize] records; older records
/// are dropped silently. This protects against runaway growth if the metrics
/// endpoint is unreachable for an extended period.
class SlotOutcomeBufferRepository {
  static final SlotOutcomeBufferRepository instance =
      SlotOutcomeBufferRepository._();
  SlotOutcomeBufferRepository._();

  SharedPreferences? _prefs;
  Future<SharedPreferences>? _prefsFuture;

  static const String _keyBase = 'slot_outcome_buffer';
  static const int _maxBufferSize = 200;

  static String get _key => NetworkPrefs.prefixKey(_keyBase);

  /// Serialises mutating ops so concurrent appends/discards from the
  /// monitor + reporting timer don't lose writes via read-modify-write
  /// races.
  Future<void> _writeLock = Future<void>.value();

  /// Lazy-init: callers don't have to remember to call this. First [append],
  /// [drain], or [discard] will trigger it. Returns `true` once prefs are
  /// resolved; `false` only if `SharedPreferences.getInstance()` throws.
  Future<bool> _ensureReady() async {
    if (_prefs != null) return true;
    try {
      _prefsFuture ??= SharedPreferences.getInstance();
      _prefs = await _prefsFuture!;
      return true;
    } catch (e) {
      _prefsFuture = null;
      _log.error('SharedPreferences init failed: $e');
      return false;
    }
  }

  /// Append a single report to the buffer. Trims oldest records if the
  /// buffer would exceed [_maxBufferSize]. Idempotent on `id`.
  Future<void> append(SlotOutcomeReport report) async {
    if (!await _ensureReady()) {
      _log.warn('append() skipped: prefs unavailable');
      return;
    }
    await _runExclusive(() async {
      final all = await _readAll();
      // Idempotent: drop any existing record with the same id (newer wins).
      all.removeWhere((r) => r.id == report.id);
      all.add(report);
      // Trim oldest if over cap.
      if (all.length > _maxBufferSize) {
        all.sort((a, b) => a.capturedAtMs.compareTo(b.capturedAtMs));
        all.removeRange(0, all.length - _maxBufferSize);
      }
      await _writeAll(all);
      _log.debug(
        'Buffered slot outcome',
        context: {
          'id': report.id,
          'global_slot': report.globalSlot,
          'outcome': report.outcome.name,
          'pending': all.length,
        },
      );
    });
  }

  /// Read-only snapshot of all pending reports. Does not remove anything;
  /// use [discard] after a successful POST.
  Future<List<SlotOutcomeReport>> drain() async {
    if (!await _ensureReady()) return const [];
    return _readAll();
  }

  /// Discard reports with the given ids (called after a 2xx POST).
  Future<void> discard(Iterable<String> ids) async {
    if (!await _ensureReady()) return;
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;
    await _runExclusive(() async {
      final all = await _readAll();
      final before = all.length;
      all.removeWhere((r) => idSet.contains(r.id));
      if (all.length != before) {
        await _writeAll(all);
        _log.debug(
          'Discarded shipped slot outcomes',
          context: {
            'discarded': before - all.length,
            'pending': all.length,
          },
        );
      }
    });
  }

  /// Test/maintenance helper: drop every buffered record.
  Future<void> clearAll() async {
    if (!await _ensureReady()) return;
    await _runExclusive(() async {
      await _prefs?.remove(_key);
      _log.info('Cleared slot outcome buffer');
    });
  }

  /// Always returns a growable list — callers (`append`, `discard`) mutate
  /// it before writing back. Empty results must be growable too.
  Future<List<SlotOutcomeReport>> _readAll() async {
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) return <SlotOutcomeReport>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => SlotOutcomeReport.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: true);
    } catch (e) {
      _log.error(
        'Buffer JSON parse failed; resetting',
        context: {'error': e.toString()},
      );
      await _prefs?.remove(_key);
      return <SlotOutcomeReport>[];
    }
  }

  Future<void> _writeAll(List<SlotOutcomeReport> reports) async {
    if (reports.isEmpty) {
      await _prefs?.remove(_key);
      return;
    }
    final encoded = jsonEncode(reports.map((r) => r.toJson()).toList());
    await _prefs?.setString(_key, encoded);
  }

  /// Chains the next mutation onto [_writeLock] so reads and writes happen
  /// in submission order. Errors from [op] are surfaced to the caller but
  /// swallowed by the lock chain so subsequent callers don't deadlock.
  Future<void> _runExclusive(Future<void> Function() op) {
    final completer = Completer<void>();
    final previous = _writeLock;
    // Errors are swallowed here so the chain stays usable; the caller still
    // gets the original error via [completer.future] below.
    _writeLock = completer.future.catchError((_) {});
    previous.whenComplete(() async {
      try {
        await op();
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
