import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart' as rust;
import 'package:crypto_mobile_app/core/config/theme_mode.dart';
import 'package:crypto_mobile_app/core/config/debug_mode.dart';
import 'package:crypto_mobile_app/core/services/http_debug_log_store.dart';
import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log = LoggingService.instance.withTag('usernode/Providers');

// Derived async providers
final hasAnyAccountProvider = FutureProvider<bool>((ref) async {
  _log.debug('hasAnyAccountProvider: evaluating...');
  final repo = await AccountsRepository.create();
  final result = await repo.hasAny();
  _log.debug('hasAnyAccountProvider: result = $result');
  return result;
});

// Backend lifecycle manager. Node STARTS are platform-controlled (SV chrome
// requests them over bridge v4). Account presence alone is not authority: only
// a signed-in, ready identity may arm recovery. Guest/keyless node support is
// deliberately dormant until its product mode is defined.
final backendLifecycleProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<bool>>(
    hasAnyAccountProvider,
    (previous, next) async {
      final prevHasAccount = previous?.value ?? false;
      final nextHasAccount = next.value ?? false;

      if (prevHasAccount != nextHasAccount) {
        final identity = ref.read(identityProvider);
        final producerEligible = nextHasAccount && identity.allowsNodeStart;

        // Removal tears down the runtime + Android production support. An
        // addition arms watchdog recovery only after identity ownership is
        // ready; the platform still requests the node start explicitly.
        _log.trace(
          'Account presence changed ($prevHasAccount → $nextHasAccount) - '
          'producer eligibility: $producerEligible',
        );
        await NodeLifecycleCoordinator.instance.reportAccountsChanged(
          hasAccount: producerEligible,
          reason: producerEligible
              ? 'ready_account_added'
              : 'account_removed_or_identity_ineligible',
        );
      }
    },
  );

  return;
});

// Build environment from Rust bindings
final buildEnvProvider = Provider((ref) => rust.buildInfo());

// Theme mode controller with persistence
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _init();
  }

  Future<void> _init() async {
    final saved = await ThemeModeStorage.load();
    state = saved;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});

// Debug mode controller with persistence. When enabled, the app captures HTTP
// traffic into [HttpDebugLogStore] (off by default).
class DebugModeController extends StateNotifier<bool> {
  DebugModeController() : super(DebugModeStorage.isEnabled) {
    _init();
  }

  Future<void> _init() async {
    state = await DebugModeStorage.load();
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    await DebugModeStorage.save(enabled);
  }
}

final debugModeProvider =
    StateNotifierProvider<DebugModeController, bool>((ref) {
  return DebugModeController();
});

/// Exposes the in-memory HTTP debug log buffer to the viewer UI.
final httpDebugLogStoreProvider =
    Provider<HttpDebugLogStore>((ref) => HttpDebugLogStore.instance);
