import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app sleep flag used by both UI and headless runtimes.
class AppSleepStateStore {
  AppSleepStateStore._();

  static const _sleepingKey = 'app_sleep:is_sleeping';
  static bool _isSleeping = false;

  static bool get isSleeping => _isSleeping;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isSleeping = prefs.getBool(_sleepingKey) ?? false;
  }

  static Future<void> setSleeping(bool value) async {
    _isSleeping = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sleepingKey, value);
  }
}
