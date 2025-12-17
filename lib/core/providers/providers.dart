import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/features/wallet/accounts_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart' as rust;
import 'package:crypto_mobile_app/core/config/theme_mode.dart';
import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

final _log = LoggingService.instance.withTag('usernode/Providers');

// Derived async providers
final hasAnyAccountProvider = FutureProvider<bool>((ref) async {
  _log.debug('hasAnyAccountProvider: evaluating...');
  final repo = await AccountsRepository.create();
  final result = await repo.hasAny();
  _log.debug('hasAnyAccountProvider: result = $result');
  return result;
});

// Onboarding completion provider (network-prefixed)
const _kOnboardingCompletedKeyBase = 'onboarding:completed';

final hasCompletedOnboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final key = NetworkPrefs.prefixKey(_kOnboardingCompletedKeyBase);
  return prefs.getBool(key) ?? false;
});

Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  final key = NetworkPrefs.prefixKey(_kOnboardingCompletedKeyBase);
  await prefs.setBool(key, true);
}

// Backend lifecycle manager - automatically starts/stops based on account state
final backendLifecycleProvider = Provider<void>((ref) {
  // Watch for account state changes
  ref.listen<AsyncValue<bool>>(
    hasAnyAccountProvider,
    (previous, next) async {
      final prevHasAccount = previous?.value ?? false;
      final nextHasAccount = next.value ?? false;

      // Account created/imported: false → true
      if (!prevHasAccount && nextHasAccount) {
        _log.trace('Account created - starting backend');
        await RustBackendService.instance.startNode();
      }

      // Account deleted: true → false
      if (prevHasAccount && !nextHasAccount) {
        _log.trace('Account deleted - stopping backend');
        await RustBackendService.instance.stopNode();
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

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ThemeModeStorage.save(mode);
  }

  Future<void> cycle() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await set(next);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});

// Current network provider for reactive network state tracking
class CurrentNetworkController extends StateNotifier<String> {
  CurrentNetworkController() : super('testnet') {
    _init();
  }

  Future<void> _init() async {
    // Initialize from cached network value
    state = NetworkPrefs.currentNetwork;
  }

  Future<void> refresh() async {
    // Force refresh from SharedPreferences
    final newNetwork = await NetworkPrefs.getNetwork();
    if (mounted) {
      state = newNetwork;
    }
  }

  void updateNetwork(String network) {
    if (mounted) {
      state = network;
    }
  }
}

final currentNetworkProvider =
    StateNotifierProvider<CurrentNetworkController, String>((ref) {
  return CurrentNetworkController();
});
