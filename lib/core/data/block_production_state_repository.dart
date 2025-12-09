import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import '../models/block_production_state.dart';

final _log = LoggingService.instance.withTag('BlockProductionStateRepository');

/// Repository for persisting and loading BlockProductionState
///
/// This provides a single persistence point for all block production state,
/// replacing the scattered SharedPreferences keys used by the old services.
class BlockProductionStateRepository {
  static const String _keyStateBase = 'block_production_state';
  static String get _keyState => NetworkPrefs.prefixKey(_keyStateBase);

  BlockProductionStateRepository._();
  static final BlockProductionStateRepository instance =
      BlockProductionStateRepository._();

  /// Load the persisted state
  ///
  /// Returns BlockProductionState.initial() if no state is persisted.
  Future<BlockProductionState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString(_keyState);

      if (stateJson == null) {
        _log.debug(
            'No persisted block production state found, using initial state');
        return BlockProductionState.initial();
      }

      final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
      final state = BlockProductionState.fromJson(stateMap);

      _log.info('Loaded block production state: ${state.toString()}');
      return state;
    } catch (e, st) {
      _log.error('Error loading block production state: $e',
          error: e, stackTrace: st);
      // Return initial state on error
      return BlockProductionState.initial();
    }
  }

  /// Save the current state
  Future<void> save(BlockProductionState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = jsonEncode(state.toJson());
      await prefs.setString(_keyState, stateJson);

      _log.debug('Saved block production state: ${state.toString()}');
    } catch (e, st) {
      _log.error('Error saving block production state: $e',
          error: e, stackTrace: st);
      // Don't rethrow - state persistence failures shouldn't break the app
    }
  }

  /// Clear all persisted state
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyState);
      _log.info('Cleared block production state');
    } catch (e, st) {
      _log.error('Error clearing block production state: $e',
          error: e, stackTrace: st);
    }
  }

  /// Get a state snapshot for debugging
  Future<Map<String, dynamic>> getSnapshot() async {
    try {
      final state = await load();
      return {
        'state': state.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
