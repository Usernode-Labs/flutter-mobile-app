import 'package:shared_preferences/shared_preferences.dart';

class TransactionLimitsService {
  static const int _maxTransactionCount = 200;
  static const double _maxTransactionAmount = 1000.0;
  static const String _transactionCountKey = 'transaction_count';
  static const String _lastResetDateKey = 'last_reset_date';

  static TransactionLimitsService? _instance;
  late SharedPreferences _prefs;

  TransactionLimitsService._();

  static Future<TransactionLimitsService> getInstance() async {
    _instance ??= TransactionLimitsService._();
    await _instance!._init();
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _resetCountIfNewDay();
  }

  /// Reset transaction count if it's a new day
  Future<void> _resetCountIfNewDay() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastReset = _prefs.getString(_lastResetDateKey);

    if (lastReset != today) {
      await _prefs.setInt(_transactionCountKey, 0);
      await _prefs.setString(_lastResetDateKey, today);
    }
  }

  /// Check if user can send a transaction based on count limit
  Future<bool> canSendTransaction() async {
    await _resetCountIfNewDay();
    final currentCount = _prefs.getInt(_transactionCountKey) ?? 0;
    return currentCount < _maxTransactionCount;
  }

  /// Check if the amount is within the allowed limit
  bool isAmountValid(double amount) {
    return amount > 0 && amount <= _maxTransactionAmount;
  }

  /// Get current transaction count for today
  Future<int> getCurrentTransactionCount() async {
    await _resetCountIfNewDay();
    return _prefs.getInt(_transactionCountKey) ?? 0;
  }

  /// Get remaining transaction count for today
  Future<int> getRemainingTransactionCount() async {
    final current = await getCurrentTransactionCount();
    return _maxTransactionCount - current;
  }

  /// Increment transaction count after successful transaction
  Future<void> incrementTransactionCount() async {
    await _resetCountIfNewDay();
    final currentCount = _prefs.getInt(_transactionCountKey) ?? 0;
    await _prefs.setInt(_transactionCountKey, currentCount + 1);
  }

  /// Get transaction limits for display
  static int get maxTransactionCount => _maxTransactionCount;
  static double get maxTransactionAmount => _maxTransactionAmount;

  /// Validation error messages
  Future<String?> getTransactionCountError() async {
    if (!(await canSendTransaction())) {
      return 'Daily transaction limit reached ($_maxTransactionCount transactions per day)';
    }
    return null;
  }

  String? getAmountError(double amount) {
    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }
    if (amount > _maxTransactionAmount) {
      return 'Amount cannot exceed $_maxTransactionAmount';
    }
    return null;
  }
}
