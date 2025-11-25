import 'dart:convert';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = LoggingService.instance.withTag(LogTag.node);

/// Repository for persisting and tracking slot production statistics
///
/// Stores historical data about won slots, production attempts, successes,
/// and failures to provide insights and reliability metrics.
class SlotProductionRepository {
  static final SlotProductionRepository instance = SlotProductionRepository._();
  SlotProductionRepository._();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // In-memory cache
  final List<SlotProductionRecord> _records = [];
  SlotProductionStats? _cachedStats;

  static const String _recordsKey = 'slot_production_records';
  static const String _statsKey = 'slot_production_stats';
  static const int _maxRecordsToKeep = 500; // Keep last 500 records

  /// Initialize the repository
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      _log.info('SlotProductionRepository initializing...');
      _prefs = await SharedPreferences.getInstance();

      // Load persisted records
      await _loadRecords();
      await _loadStats();

      _initialized = true;
      _log.info(
        'SlotProductionRepository initialized with ${_records.length} records',
      );
      return true;
    } catch (e) {
      _log.error('Error initializing SlotProductionRepository: $e');
      return false;
    }
  }

  /// Record a won slot
  Future<void> recordWonSlot({
    required int slotNumber,
    required int epoch,
    required DateTime slotTime,
  }) async {
    if (!_initialized) return;

    try {
      final record = SlotProductionRecord(
        slotNumber: slotNumber,
        epoch: epoch,
        slotTime: slotTime,
        recordedAt: DateTime.now(),
        status: SlotProductionStatus.won,
      );

      _records.add(record);
      await _persistRecords();

      _log.debug('Recorded won slot: $slotNumber');
    } catch (e) {
      _log.error('Error recording won slot: $e');
    }
  }

  /// Record a slot production attempt
  Future<void> recordProductionAttempt({
    required int slotNumber,
    required DateTime attemptTime,
  }) async {
    if (!_initialized) return;

    try {
      // Find existing record or create new one
      final existingIndex = _records.indexWhere(
        (r) => r.slotNumber == slotNumber,
      );

      if (existingIndex != -1) {
        _records[existingIndex] = _records[existingIndex].copyWith(
          status: SlotProductionStatus.attempting,
          attemptTime: attemptTime,
        );
      } else {
        _log.warn('No won slot record found for slot $slotNumber');
      }

      await _persistRecords();
      _log.debug('Recorded production attempt for slot: $slotNumber');
    } catch (e) {
      _log.error('Error recording production attempt: $e');
    }
  }

  /// Record a successful slot production
  Future<void> recordProductionSuccess({
    required int slotNumber,
    required int blockHeight,
    required DateTime producedTime,
  }) async {
    if (!_initialized) return;

    try {
      final existingIndex = _records.indexWhere(
        (r) => r.slotNumber == slotNumber,
      );

      if (existingIndex != -1) {
        _records[existingIndex] = _records[existingIndex].copyWith(
          status: SlotProductionStatus.produced,
          producedTime: producedTime,
          blockHeight: blockHeight,
        );
      } else {
        _log.warn('No record found for slot $slotNumber');
      }

      await _persistRecords();
      await _updateStats(success: true);

      _log.info('Recorded production success for slot: $slotNumber');
    } catch (e) {
      _log.error('Error recording production success: $e');
    }
  }

  /// Record a failed slot production
  Future<void> recordProductionFailure({
    required int slotNumber,
    required DateTime failedTime,
    String? reason,
  }) async {
    if (!_initialized) return;

    try {
      final existingIndex = _records.indexWhere(
        (r) => r.slotNumber == slotNumber,
      );

      if (existingIndex != -1) {
        _records[existingIndex] = _records[existingIndex].copyWith(
          status: SlotProductionStatus.failed,
          failedTime: failedTime,
          failureReason: reason,
        );
      } else {
        _log.warn('No record found for slot $slotNumber');
      }

      await _persistRecords();
      await _updateStats(success: false);

      _log.info('Recorded production failure for slot: $slotNumber');
    } catch (e) {
      _log.error('Error recording production failure: $e');
    }
  }

  /// Get all records
  List<SlotProductionRecord> getAllRecords() {
    return List.unmodifiable(_records);
  }

  /// Get records for a specific epoch
  List<SlotProductionRecord> getRecordsForEpoch(int epoch) {
    return _records.where((r) => r.epoch == epoch).toList();
  }

  /// Get recent records (last N)
  List<SlotProductionRecord> getRecentRecords({int limit = 50}) {
    final sorted = List<SlotProductionRecord>.from(_records)
      ..sort((a, b) => b.slotTime.compareTo(a.slotTime));
    return sorted.take(limit).toList();
  }

  /// Get production statistics
  SlotProductionStats getStats() {
    if (_cachedStats == null) {
      _calculateStats();
    }
    return _cachedStats!;
  }

  /// Calculate statistics from records
  void _calculateStats() {
    int totalWon = 0;
    int totalProduced = 0;
    int totalFailed = 0;
    int totalAttempted = 0;

    for (final record in _records) {
      if (record.status == SlotProductionStatus.won ||
          record.status == SlotProductionStatus.attempting ||
          record.status == SlotProductionStatus.produced ||
          record.status == SlotProductionStatus.failed) {
        totalWon++;
      }

      if (record.status == SlotProductionStatus.attempting ||
          record.status == SlotProductionStatus.produced ||
          record.status == SlotProductionStatus.failed) {
        totalAttempted++;
      }

      if (record.status == SlotProductionStatus.produced) {
        totalProduced++;
      } else if (record.status == SlotProductionStatus.failed) {
        totalFailed++;
      }
    }

    final successRate =
        totalAttempted > 0 ? (totalProduced / totalAttempted * 100) : 0.0;

    _cachedStats = SlotProductionStats(
      totalWonSlots: totalWon,
      totalProduced: totalProduced,
      totalFailed: totalFailed,
      totalAttempted: totalAttempted,
      successRate: successRate,
      lastUpdated: DateTime.now(),
    );
  }

  /// Update statistics after a production attempt
  Future<void> _updateStats({required bool success}) async {
    _calculateStats();
    await _persistStats();
  }

  /// Load records from persistence
  Future<void> _loadRecords() async {
    try {
      final recordsJson = _prefs?.getString(_recordsKey);
      if (recordsJson == null) {
        _log.debug('No persisted records found');
        return;
      }

      final List<dynamic> recordsList = jsonDecode(recordsJson);
      _records.clear();
      _records.addAll(
        recordsList.map((json) => SlotProductionRecord.fromJson(json)),
      );

      _log.debug('Loaded ${_records.length} persisted records');
    } catch (e) {
      _log.error('Error loading records: $e');
    }
  }

  /// Persist records to storage
  Future<void> _persistRecords() async {
    try {
      // Keep only the most recent records to avoid unbounded growth
      if (_records.length > _maxRecordsToKeep) {
        _records.sort((a, b) => b.slotTime.compareTo(a.slotTime));
        _records.removeRange(_maxRecordsToKeep, _records.length);
      }

      final recordsJson = jsonEncode(
        _records.map((r) => r.toJson()).toList(),
      );
      await _prefs?.setString(_recordsKey, recordsJson);
    } catch (e) {
      _log.error('Error persisting records: $e');
    }
  }

  /// Load stats from persistence
  Future<void> _loadStats() async {
    try {
      final statsJson = _prefs?.getString(_statsKey);
      if (statsJson == null) {
        _calculateStats();
        return;
      }

      _cachedStats = SlotProductionStats.fromJson(jsonDecode(statsJson));
      _log.debug('Loaded persisted stats');
    } catch (e) {
      _log.error('Error loading stats: $e');
      _calculateStats();
    }
  }

  /// Persist stats to storage
  Future<void> _persistStats() async {
    try {
      if (_cachedStats == null) return;

      final statsJson = jsonEncode(_cachedStats!.toJson());
      await _prefs?.setString(_statsKey, statsJson);
    } catch (e) {
      _log.error('Error persisting stats: $e');
    }
  }

  /// Clear all records and stats
  Future<void> clearAll() async {
    _records.clear();
    _cachedStats = null;
    await _prefs?.remove(_recordsKey);
    await _prefs?.remove(_statsKey);
    _calculateStats();
    _log.info('Cleared all production records and stats');
  }

  /// Clear records older than a certain date
  Future<void> clearOldRecords(DateTime cutoffDate) async {
    final before = _records.length;
    _records.removeWhere((r) => r.slotTime.isBefore(cutoffDate));
    final after = _records.length;

    await _persistRecords();
    _calculateStats();
    await _persistStats();

    _log.info('Cleared ${before - after} old records');
  }
}

/// Status of a slot production
enum SlotProductionStatus {
  won, // Slot was won, not yet attempted
  attempting, // Currently attempting to produce
  produced, // Successfully produced block
  failed, // Failed to produce block
}

/// Record of a slot production attempt
class SlotProductionRecord {
  final int slotNumber;
  final int epoch;
  final DateTime slotTime;
  final DateTime recordedAt;
  final SlotProductionStatus status;
  final DateTime? attemptTime;
  final DateTime? producedTime;
  final DateTime? failedTime;
  final int? blockHeight;
  final String? failureReason;

  SlotProductionRecord({
    required this.slotNumber,
    required this.epoch,
    required this.slotTime,
    required this.recordedAt,
    required this.status,
    this.attemptTime,
    this.producedTime,
    this.failedTime,
    this.blockHeight,
    this.failureReason,
  });

  SlotProductionRecord copyWith({
    SlotProductionStatus? status,
    DateTime? attemptTime,
    DateTime? producedTime,
    DateTime? failedTime,
    int? blockHeight,
    String? failureReason,
  }) {
    return SlotProductionRecord(
      slotNumber: slotNumber,
      epoch: epoch,
      slotTime: slotTime,
      recordedAt: recordedAt,
      status: status ?? this.status,
      attemptTime: attemptTime ?? this.attemptTime,
      producedTime: producedTime ?? this.producedTime,
      failedTime: failedTime ?? this.failedTime,
      blockHeight: blockHeight ?? this.blockHeight,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'slotNumber': slotNumber,
        'epoch': epoch,
        'slotTime': slotTime.toIso8601String(),
        'recordedAt': recordedAt.toIso8601String(),
        'status': status.toString(),
        'attemptTime': attemptTime?.toIso8601String(),
        'producedTime': producedTime?.toIso8601String(),
        'failedTime': failedTime?.toIso8601String(),
        'blockHeight': blockHeight,
        'failureReason': failureReason,
      };

  factory SlotProductionRecord.fromJson(Map<String, dynamic> json) {
    return SlotProductionRecord(
      slotNumber: json['slotNumber'] as int,
      epoch: json['epoch'] as int,
      slotTime: DateTime.parse(json['slotTime'] as String),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      status: SlotProductionStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
      ),
      attemptTime: json['attemptTime'] != null
          ? DateTime.parse(json['attemptTime'] as String)
          : null,
      producedTime: json['producedTime'] != null
          ? DateTime.parse(json['producedTime'] as String)
          : null,
      failedTime: json['failedTime'] != null
          ? DateTime.parse(json['failedTime'] as String)
          : null,
      blockHeight: json['blockHeight'] as int?,
      failureReason: json['failureReason'] as String?,
    );
  }
}

/// Statistics about slot production
class SlotProductionStats {
  final int totalWonSlots;
  final int totalProduced;
  final int totalFailed;
  final int totalAttempted;
  final double successRate;
  final DateTime lastUpdated;

  SlotProductionStats({
    required this.totalWonSlots,
    required this.totalProduced,
    required this.totalFailed,
    required this.totalAttempted,
    required this.successRate,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'totalWonSlots': totalWonSlots,
        'totalProduced': totalProduced,
        'totalFailed': totalFailed,
        'totalAttempted': totalAttempted,
        'successRate': successRate,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory SlotProductionStats.fromJson(Map<String, dynamic> json) {
    return SlotProductionStats(
      totalWonSlots: json['totalWonSlots'] as int,
      totalProduced: json['totalProduced'] as int,
      totalFailed: json['totalFailed'] as int,
      totalAttempted: json['totalAttempted'] as int,
      successRate: (json['successRate'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  @override
  String toString() {
    return 'SlotProductionStats('
        'won: $totalWonSlots, '
        'produced: $totalProduced, '
        'failed: $totalFailed, '
        'rate: ${successRate.toStringAsFixed(1)}%'
        ')';
  }
}
