import 'package:shared_preferences/shared_preferences.dart';

/// Persisted product sleep preference used by the exact session operation.
///
/// TODO(session-power): Reintroduce automatic inactivity/lifecycle driving in
/// a separately reviewed alarm/power slice. This lifecycle cutover stores the
/// preference and exposes exact session-scoped sleep operations, but does not
/// automatically pause the runtime after five minutes or on app lifecycle
/// changes.
class AppSleepStateStore {
  AppSleepStateStore._();

  static const _sleepingKey = 'app_sleep:is_sleeping';
  static const _enabledKey = 'app_sleep:is_enabled';
  static bool _isSleeping = false;
  static bool _isEnabled = true;

  static bool get isSleeping => _isSleeping;
  static bool get isEnabled => _isEnabled;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? true;
    final storedSleeping = prefs.getBool(_sleepingKey) ?? false;
    _isSleeping = _isEnabled && storedSleeping;

    if (!_isEnabled && storedSleeping) {
      await prefs.setBool(_sleepingKey, false);
    }
  }

  static Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);

    if (!value) {
      _isSleeping = false;
      await prefs.setBool(_sleepingKey, false);
    }
  }

  static Future<void> setSleeping(bool value) async {
    _isSleeping = _isEnabled ? value : false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sleepingKey, _isSleeping);
  }
}
