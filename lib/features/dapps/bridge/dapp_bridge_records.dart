part of '../dapp_webview_screen.dart';

enum _TxStatus { denied, error, queued }

class _TxRecord {
  final String id;
  final DateTime sentAt;
  final String from;
  final String to;
  final BigInt amount;
  final String memo;
  final _TxStatus status;
  final String? errorMessage;
  final DateTime? confirmedAt;
  final int? inclusionLatencyMs;
  final int? blockHeight;
  final int? onChainTimestampMs;
  final String? onChainStatus;
  // Wall-clock ms of when the dapp's bridge poll (or an explicit
  // window.usernode.acknowledgeTransaction call) first surfaced this tx
  // on-chain. Independent of [confirmedAt], which is the slower
  // explorer-poll observation. The first ack wins so this stays stable
  // across re-polls, refreshes, and explicit calls.
  final int? dappObservedAtMs;

  const _TxRecord({
    required this.id,
    required this.sentAt,
    required this.from,
    required this.to,
    required this.amount,
    required this.memo,
    required this.status,
    this.errorMessage,
    this.confirmedAt,
    this.inclusionLatencyMs,
    this.blockHeight,
    this.onChainTimestampMs,
    this.onChainStatus,
    this.dappObservedAtMs,
  });

  _TxRecord copyWith({
    DateTime? confirmedAt,
    int? inclusionLatencyMs,
    int? blockHeight,
    int? onChainTimestampMs,
    String? onChainStatus,
    int? dappObservedAtMs,
  }) {
    return _TxRecord(
      id: id,
      sentAt: sentAt,
      from: from,
      to: to,
      amount: amount,
      memo: memo,
      status: status,
      errorMessage: errorMessage,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      inclusionLatencyMs: inclusionLatencyMs ?? this.inclusionLatencyMs,
      blockHeight: blockHeight ?? this.blockHeight,
      onChainTimestampMs: onChainTimestampMs ?? this.onChainTimestampMs,
      onChainStatus: onChainStatus ?? this.onChainStatus,
      dappObservedAtMs: dappObservedAtMs ?? this.dappObservedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sentAt': sentAt.millisecondsSinceEpoch,
        'from': from,
        'to': to,
        'amount': amount.toString(),
        'memo': memo,
        'status': status.name,
        if (errorMessage != null) 'error': errorMessage,
        if (confirmedAt != null)
          'confirmedAt': confirmedAt!.millisecondsSinceEpoch,
        if (inclusionLatencyMs != null)
          'inclusionLatencyMs': inclusionLatencyMs,
        if (blockHeight != null) 'blockHeight': blockHeight,
        if (onChainTimestampMs != null)
          'onChainTimestampMs': onChainTimestampMs,
        if (onChainStatus != null) 'onChainStatus': onChainStatus,
        if (dappObservedAtMs != null) 'dappObservedAtMs': dappObservedAtMs,
      };

  // ── Latency helpers ─────────────────────────────────────────────────────
  //
  // Two independent observation channels feed timing data: the explorer poll
  // (sets `confirmedAt` + `inclusionLatencyMs`) and the dapp ack via the
  // bridge's `txObserved` JS-channel message (sets `dappObservedAtMs`,
  // optionally also `inclusionLatencyMs` when the bridge had a matched tx
  // in hand).
  //
  // Each channel contributes a "total" (observed_at − sentAt) and, when
  // inclusion latency is also known, a "last mile" (total − inclusion).
  // The fastest signal wins for the headline metrics, but the per-channel
  // numbers are still exposed so the latency row can show both side-by-side.
  int get _sentMs => sentAt.millisecondsSinceEpoch;

  int? get explorerTotalMs {
    if (confirmedAt == null) return null;
    final ms = confirmedAt!.millisecondsSinceEpoch - _sentMs;
    return ms >= 0 ? ms : null;
  }

  int? get dappTotalMs {
    if (dappObservedAtMs == null) return null;
    final ms = dappObservedAtMs! - _sentMs;
    return ms >= 0 ? ms : null;
  }

  int? get bestTotalMs {
    final e = explorerTotalMs;
    final d = dappTotalMs;
    if (e != null && d != null) return e < d ? e : d;
    return e ?? d;
  }

  int? get explorerLastMileMs {
    final e = explorerTotalMs;
    final inc = inclusionLatencyMs;
    if (e == null || inc == null) return null;
    final lm = e - inc;
    return lm >= 0 ? lm : null;
  }

  int? get dappLastMileMs {
    final d = dappTotalMs;
    final inc = inclusionLatencyMs;
    if (d == null || inc == null) return null;
    final lm = d - inc;
    return lm >= 0 ? lm : null;
  }

  factory _TxRecord.fromJson(Map<String, dynamic> j) {
    return _TxRecord(
      id: j['id'] as String,
      sentAt: DateTime.fromMillisecondsSinceEpoch(j['sentAt'] as int),
      from: j['from'] as String,
      to: j['to'] as String,
      amount: BigInt.parse(j['amount'] as String),
      memo: j['memo'] as String,
      status: _TxStatus.values.byName(j['status'] as String),
      errorMessage: j['error'] as String?,
      confirmedAt: j['confirmedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(j['confirmedAt'] as int)
          : null,
      inclusionLatencyMs: (j['inclusionLatencyMs'] as num?)?.toInt(),
      blockHeight: (j['blockHeight'] as num?)?.toInt(),
      onChainTimestampMs: (j['onChainTimestampMs'] as num?)?.toInt(),
      onChainStatus: j['onChainStatus'] as String?,
      dappObservedAtMs: (j['dappObservedAtMs'] as num?)?.toInt(),
    );
  }
}

/// Dapp transaction receipts: the persisted [_TxRecord] store backing
/// the native receipts sheet and the `getTransactionRecords` /
/// `txObserved` bridge methods, plus the explorer confirmation poller.
mixin _BridgeTxRecords on _DappWebViewScreenStateBase {
  final Set<String> _dappTxIds = {};
  final Map<String, _TxRecord> _txRecords = {};
  Timer? _confirmPoller;
  String? _cachedChainId;

  static const _maxPersistedIds = 200;
  static const _maxTxRecords = 500;

  /// The identity bucket these receipts belong to, captured when the store was
  /// bound (see [_bindTxRecordsToActiveIdentity]) rather than resolved per
  /// access — a save that lands after a sign-out must still address the
  /// records it loaded.
  String? _recordsBucket;

  static const _dappTxIdsKeyBase = 'dapp_tx_ids';
  static const _txRecordsKeyBase = 'tx_records';

  /// Receipts carry sender, recipient, amount, memo, status and timing, so
  /// they are account-scoped state, not per-URL state. Keying them by URL
  /// alone (as they were) meant every replacement WebView on the same URL
  /// loaded them, and `getTransactionRecords` handed the previous user's
  /// transfers to whoever signed in next.
  String _recordsKey(String base) => NetworkPrefs.prefixAccountKeyFor(
        '$base:${widget.url}',
        _recordsBucket ?? NetworkPrefs.activeBucket,
      );

  String get _dappTxIdsPrefsKey => _recordsKey(_dappTxIdsKeyBase);
  String get _txRecordsPrefsKey => _recordsKey(_txRecordsKeyBase);

  /// The bucket a transaction operation must write its receipt to.
  ///
  /// Captured at the START of the operation, because [_recordsBucket] is
  /// mutable shared state: a send awaits user confirmation and then an RPC, and
  /// a sign-out during either rebinds the owner to guest/the successor. A
  /// receipt carries sender, recipient, amount and memo, so it follows the
  /// identity that made the transaction, not whoever owns the screen when the
  /// RPC returns.
  String get _activeRecordsBucket =>
      _recordsBucket ?? NetworkPrefs.activeBucket;

  /// Points the in-memory receipt maps at the bucket that owns the app right
  /// now, reloading from scratch when the identity changed. Called on mount
  /// and from the identity listener, so a sign-out empties the maps before the
  /// next identity can read them out of memory.
  Future<void> _bindTxRecordsToActiveIdentity() async {
    final bucket = NetworkPrefs.activeBucket;
    if (_recordsBucket == bucket) return;
    _recordsBucket = bucket;
    _confirmPoller?.cancel();
    _confirmPoller = null;
    _dappTxIds.clear();
    _txRecords.clear();
    await _removeUnbucketedRecords();
    await _loadDappTxIds();
    await _loadTxRecords();
    if (mounted) setState(() {});
  }

  /// Drops the pre-bucket keys. They belong to a user this app can no longer
  /// identify, so they are removed rather than adopted by whoever opens the
  /// dapp first.
  Future<void> _removeUnbucketedRecords() async {
    final prefs = await SharedPreferences.getInstance();
    for (final base in const [_dappTxIdsKeyBase, _txRecordsKeyBase]) {
      await prefs.remove('$base:${widget.url}');
    }
  }

  Future<void> _loadDappTxIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dappTxIdsPrefsKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _dappTxIds.addAll(list.cast<String>());
    } catch (_) {}
  }

  Future<void> _saveDappTxIds({String? bucket}) async {
    final prefs = await SharedPreferences.getInstance();
    if (_dappTxIds.length > _maxPersistedIds) {
      final sorted =
          _dappTxIds.where((id) => _txRecords.containsKey(id)).toList()
            ..sort((a, b) {
              final ra = _txRecords[a]!;
              final rb = _txRecords[b]!;
              return rb.sentAt.compareTo(ra.sentAt);
            });
      final kept = sorted.take(_maxPersistedIds).toSet();
      _dappTxIds
        ..clear()
        ..addAll(kept);
    }
    await prefs.setString(
      bucket == null
          ? _dappTxIdsPrefsKey
          : NetworkPrefs.prefixAccountKeyFor(
              '$_dappTxIdsKeyBase:${widget.url}', bucket),
      jsonEncode(_dappTxIds.toList()),
    );
  }

  Future<void> _loadTxRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_txRecordsPrefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        _txRecords[entry.key] =
            _TxRecord.fromJson(entry.value as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _saveTxRecords({String? bucket}) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _txRecords.entries.toList()
      ..sort((a, b) => b.value.sentAt.compareTo(a.value.sentAt));

    final map = <String, dynamic>{};
    for (final e in entries.take(_maxTxRecords)) {
      map[e.key] = e.value.toJson();
    }

    if (entries.length > _maxTxRecords) {
      final kept = entries.take(_maxTxRecords).map((e) => e.key).toSet();
      _txRecords.removeWhere((k, _) => !kept.contains(k));
    }

    await prefs.setString(
      bucket == null
          ? _txRecordsPrefsKey
          : NetworkPrefs.prefixAccountKeyFor(
              '$_txRecordsKeyBase:${widget.url}', bucket),
      jsonEncode(map),
    );
  }

  // Stamp a tx with the wall-clock time the dapp's bridge first observed
  // it on-chain, surfaced via the `txObserved` JS channel message. Distinct
  // from [_TxRecord.confirmedAt], which is set by our own (slower) explorer
  // poll. First ack wins so re-emits and explicit acks don't reset the
  // timestamp.
  //
  // When the bridge has the matched tx in hand (the typical post-send
  // inclusion-poll path), it also forwards `block_height` and
  // `block_timestamp_ms`. We use those to populate the same fields the
  // explorer poll sets (`onChainStatus`, `blockHeight`, `onChainTimestampMs`,
  // `inclusionLatencyMs`) so the badge, the header pill, and the
  // inclusion / last-mile columns can all flip to "confirmed" without
  // waiting on the slower explorer poll. Explicit
  // `window.usernode.acknowledgeTransaction(txId)` callers don't have a
  // matched tx and just omit those fields — we still mark the tx confirmed
  // (the ack itself is evidence the tx is on chain) but leave inclusion
  // metrics for the explorer poll to fill in later.
  Future<void> _handleTxObserved(Map<String, dynamic> payload) async {
    final args = payload['args'];
    if (args is! Map<String, dynamic>) return;
    final txId = (args['tx_id'] as String?)?.trim();
    final observedAtMs = (args['observed_at_ms'] as num?)?.toInt();
    if (txId == null || txId.isEmpty || observedAtMs == null) return;

    final rec = _txRecords[txId];
    if (rec == null) return;
    if (rec.dappObservedAtMs != null) return;

    final blockHeight = (args['block_height'] as num?)?.toInt();
    final blockTimestampMs = (args['block_timestamp_ms'] as num?)?.toInt();

    // Inclusion latency = block timestamp − sent timestamp. Skip when we
    // can't compute it (no block_timestamp_ms, or negative due to clock
    // skew between phone and node).
    int? inclusionLatencyMs;
    if (blockTimestampMs != null) {
      final ms = blockTimestampMs - rec.sentAt.millisecondsSinceEpoch;
      if (ms >= 0) inclusionLatencyMs = ms;
    }

    final updated = rec.copyWith(
      dappObservedAtMs: observedAtMs,
      // Don't clobber values the explorer poll may have already filled in.
      onChainStatus: rec.onChainStatus ?? 'confirmed',
      blockHeight: rec.blockHeight ?? blockHeight,
      onChainTimestampMs: rec.onChainTimestampMs ?? blockTimestampMs,
      inclusionLatencyMs: rec.inclusionLatencyMs ?? inclusionLatencyMs,
    );
    if (mounted) {
      setState(() {
        _txRecords[txId] = updated;
      });
    } else {
      _txRecords[txId] = updated;
    }
    await _saveTxRecords();
  }

  /// Persists [record] into [bucket] — the bucket captured when the operation
  /// STARTED (see [_activeRecordsBucket]).
  ///
  /// The in-memory maps are only updated when that bucket is still the bound
  /// one; otherwise the receipt is written to its owner's bucket and left out
  /// of the successor's view.
  void _addRecord(_TxRecord record, {required String bucket}) {
    final stillBound = bucket == (_recordsBucket ?? NetworkPrefs.activeBucket);
    if (stillBound) {
      _dappTxIds.add(record.id);
      _txRecords[record.id] = record;
      _saveDappTxIds(bucket: bucket);
      _saveTxRecords(bucket: bucket);
      return;
    }
    unawaited(_appendRecordToRetiredBucket(record, bucket));
  }

  /// Writes a receipt whose owner is no longer the bound identity, without
  /// letting it touch the live maps.
  Future<void> _appendRecordToRetiredBucket(
    _TxRecord record,
    String bucket,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final idsKey = NetworkPrefs.prefixAccountKeyFor(
        '$_dappTxIdsKeyBase:${widget.url}', bucket);
    final recordsKey = NetworkPrefs.prefixAccountKeyFor(
        '$_txRecordsKeyBase:${widget.url}', bucket);
    try {
      final ids = <String>{
        ...((jsonDecode(prefs.getString(idsKey) ?? '[]') as List<dynamic>)
            .cast<String>()),
        record.id,
      };
      final records = <String, dynamic>{
        ...((jsonDecode(prefs.getString(recordsKey) ?? '{}')
            as Map<String, dynamic>)),
        record.id: record.toJson(),
      };
      await prefs.setString(idsKey, jsonEncode(ids.toList()));
      await prefs.setString(recordsKey, jsonEncode(records));
    } catch (_) {
      // A receipt is a convenience record; a corrupt store must not fail the
      // transaction that produced it.
    }
  }

  /// Returns this webview's persisted dapp-transaction receipts (the same
  /// `_TxRecord` list backing the native receipts sheet), newest first.
  Future<void> _handleGetTransactionRecords(String id) async {
    final records = _txRecords.values.toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    await _resolveJsPromise(
      id: id,
      value: {
        'items': [for (final r in records.take(100)) r.toJson()],
      },
      error: null,
    );
  }

  void _ensureConfirmPoller() {
    if (_confirmPoller != null) return;
    _confirmPoller = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollForConfirmations();
    });
  }

  Future<void> _pollForConfirmations() async {
    final pending = <String, DateTime>{};
    for (final id in _dappTxIds) {
      final rec = _txRecords[id];
      if (rec == null) continue;
      if (rec.status != _TxStatus.queued) continue;
      if (rec.id.startsWith('local_')) continue;
      if (rec.confirmedAt != null) continue;
      pending[rec.id] = rec.sentAt;
    }

    if (pending.isEmpty) {
      _confirmPoller?.cancel();
      _confirmPoller = null;
      return;
    }

    final address = _bridgeWalletIdentity()?.address;
    if (address == null || address.isEmpty) return;

    final dappUri = parseDappUrl(widget.url);
    final base = Uri(
      scheme: dappUri.scheme,
      host: dappUri.host,
      port: dappUri.port,
    );

    try {
      if (_cachedChainId == null) {
        final chainRes =
            await http.get(base.resolve('/explorer-api/active_chain'));
        if (chainRes.statusCode != 200) return;
        final chainData = jsonDecode(chainRes.body) as Map<String, dynamic>;
        _cachedChainId = chainData['chain_id'] as String?;
        if (_cachedChainId == null) return;
      }

      final earliest = pending.values.reduce(
        (a, b) => a.isBefore(b) ? a : b,
      );
      final fromTs = earliest.millisecondsSinceEpoch - 60000;

      final txUrl = base.resolve('/explorer-api/$_cachedChainId/transactions');
      final txRes = await http.post(
        txUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': address,
          'from_timestamp': fromTs,
          'limit': 50,
        }),
      );
      if (txRes.statusCode != 200) return;

      final txData = jsonDecode(txRes.body) as Map<String, dynamic>;
      final items = (txData['items'] as List<dynamic>?) ?? [];
      final now = DateTime.now();
      var found = false;

      for (final item in items) {
        final j = item as Map<String, dynamic>;
        final txId =
            (j['tx_id'] ?? j['id'] ?? j['txid'] ?? j['hash'] ?? '') as String;
        final status = j['status'] as String?;
        if (txId.isNotEmpty &&
            status == 'confirmed' &&
            pending.containsKey(txId)) {
          final rec = _txRecords[txId];
          if (rec != null && rec.confirmedAt == null) {
            _txRecords[txId] = rec.copyWith(
              confirmedAt: now,
              inclusionLatencyMs: (j['inclusion_latency_ms'] as num?)?.toInt(),
              blockHeight: (j['block_height'] as num?)?.toInt(),
              onChainTimestampMs: (j['timestamp_ms'] as num?)?.toInt(),
              onChainStatus: status,
            );
            found = true;
          }
        }
      }

      if (found) {
        _saveTxRecords();
        if (mounted) setState(() {});
      }
    } catch (_) {
      // Silently ignore — will retry on next tick.
    }
  }
}
