import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:crypto_mobile_app/features/node/domain/repositories/node_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/node_repository_impl.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart' as rust;
import 'package:crypto_mobile_app/core/theme/theme_mode.dart';
import 'package:flutter/material.dart';

// Repositories
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepositoryImpl.instance;
});

final nodeRepositoryProvider = Provider<NodeRepository>((ref) {
  return NodeRepositoryImpl.instance;
});

// Derived async providers
final hasAnyAccountProvider = FutureProvider<bool>((ref) async {
  final repo = await AccountsRepository.create();
  return repo.hasAny();
});

// Build environment from Rust bindings
final buildEnvProvider = Provider((ref) => rust.buildEnv());

// Feature flag to toggle Result-based providers in UI without breaking defaults.
final useResultProvidersProvider = Provider<bool>((ref) {
  const v = bool.fromEnvironment('USE_RESULT_PROVIDERS', defaultValue: false);
  return v;
});

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
