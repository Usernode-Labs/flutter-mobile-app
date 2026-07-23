import 'dart:core';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Central place to manage app feature availability.
///
/// Defaults can be overridden at build time using:
///   flutter run --dart-define=ENABLED_FEATURES=home,wallet,dapps,profile
/// or
///   flutter run --dart-define=ENABLED_FEATURES=all
enum AppFeature { settings, node }

class FeatureFlags {
  /// Ordered list used to render navigation and related UI deterministically.
  static final List<AppFeature> ordered = [
    AppFeature.node,
    AppFeature.settings,
  ];

  /// Additional granular feature keys, e.g. 'wallet.send', 'home.bridgeCard'.
  ///
  /// Parse these directly rather than relying on `_enabled`'s lazy
  /// initializer: shell routing reads a granular flag before any top-level
  /// feature, so `_loadEnabledFromEnv()` may not have run yet.
  static final Set<String> _tagsEnabled =
      _granularTagsFromEnv('ENABLED_FEATURES');
  static final Set<String> _tagsDisabled =
      _granularTagsFromEnv('DISABLED_FEATURES');

  /// Compute enabled set from compile-time env or fallback defaults.
  ///
  /// This must be initialized after the granular tag sets: the environment
  /// parser populates those sets as a side effect.
  static Set<AppFeature> _enabled = _loadEnabledFromEnv();

  static bool isEnabled(AppFeature feature) => _enabled.contains(feature);

  /// Returns whether a granular feature key is on.
  ///
  /// If key appears in `disabled`, returns false.
  /// If key appears in `enabled`, returns true.
  /// Otherwise returns [defaultOn] (true by default so existing UI keeps working).
  static bool on(String key, {bool defaultOn = true}) {
    if (_tagsDisabled.contains(key)) return false;
    if (_tagsEnabled.contains(key)) return true;
    return defaultOn;
  }

  /// Full-screen SV shell mode (app-as-SV-chrome migration): `/home` renders
  /// the Social Vibecoding webapp full-bleed — no bottom nav, no native top
  /// bar — with SV's own header providing node status / wallet / challenges.
  /// Default off; enable with `--dart-define=ENABLED_FEATURES=shell.sv` or
  /// `"enabled": ["shell.sv"]` in assets/feature_flags.json. Rollback is
  /// flipping the flag — the native tab shell stays intact behind it.
  static bool get svShellEnabled => on('shell.sv', defaultOn: false);

  /// Load flags from `assets/feature_flags.json` if present.
  /// Schema example:
  /// {
  ///   "enabled": ["home", "node"],
  ///   "order": ["home", "wallet", "node"]
  /// }
  static Future<void> loadFromAssetIfAvailable() async {
    try {
      final raw = await rootBundle.loadString('assets/feature_flags.json');
      final jsonMap = json.decode(raw) as Map<String, dynamic>;

      final enabledItems = (jsonMap['enabled'] as List<dynamic>? ?? [])
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      final disabledItems = (jsonMap['disabled'] as List<dynamic>? ?? [])
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);

      // Reset tags each time we load from asset
      _tagsEnabled
        ..clear()
        ..addAll(enabledItems)
        // Asset flags augment compile-time flags; they must not erase a
        // rollout flag such as `--dart-define=ENABLED_FEATURES=shell.sv`
        // after the router has already rendered.
        ..addAll(_granularTagsFromEnv('ENABLED_FEATURES'));
      _tagsDisabled
        ..clear()
        ..addAll(disabledItems)
        ..addAll(_granularTagsFromEnv('DISABLED_FEATURES'));

      // Map any recognized top-level features from enabled/disabled
      final mappedEnabled = <AppFeature>{};
      for (final item in enabledItems) {
        final f = _fromString(item);
        if (f != null) mappedEnabled.add(f);
      }
      if (mappedEnabled.isNotEmpty) {
        _enabled = mappedEnabled;
      }
      for (final item in disabledItems) {
        final f = _fromString(item);
        if (f != null) _enabled.remove(f);
      }

      final order = (jsonMap['order'] as List<dynamic>? ?? [])
          .map((e) => _fromString('$e'))
          .whereType<AppFeature>()
          .toList();
      if (order.isNotEmpty) {
        ordered
          ..clear()
          ..addAll(order);
      }
    } catch (_) {
      // Asset not found or invalid JSON: ignore and keep existing values.
    }
  }

  static AppFeature? _fromString(String s) {
    switch (s.toLowerCase()) {
      case 'settings':
        return AppFeature.settings;
      case 'node':
        return AppFeature.node;
      default:
        return null;
    }
  }

  static Set<AppFeature> _loadEnabledFromEnv() {
    const csv = String.fromEnvironment('ENABLED_FEATURES', defaultValue: '');
    const csvDisabled =
        String.fromEnvironment('DISABLED_FEATURES', defaultValue: '');
    if (csv.trim().isEmpty) {
      return {
        AppFeature.node,
        AppFeature.settings,
      };
    }
    final value = csv.trim().toLowerCase();
    if (value == 'all') {
      return Set<AppFeature>.from(AppFeature.values);
    }
    final parts = value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final mapped = <AppFeature>{};
    for (final p in parts) {
      final f = _fromString(p);
      if (f != null) {
        mapped.add(f);
      } else {
        _tagsEnabled.add(p);
      }
    }
    // Apply disabled env overrides for granular keys
    if (csvDisabled.trim().isNotEmpty) {
      final disabledParts = csvDisabled
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      for (final p in disabledParts) {
        final f = _fromString(p);
        if (f != null) {
          mapped.remove(f);
        } else {
          _tagsDisabled.add(p);
        }
      }
    }
    // Safety: ensure at least Node exists to avoid empty nav.
    if (mapped.isEmpty) mapped.add(AppFeature.node);
    return mapped;
  }

  static Set<String> _granularTagsFromEnv(String name) {
    final csv = name == 'ENABLED_FEATURES'
        ? const String.fromEnvironment('ENABLED_FEATURES', defaultValue: '')
        : const String.fromEnvironment('DISABLED_FEATURES', defaultValue: '');
    if (csv.trim().isEmpty || csv.trim().toLowerCase() == 'all') {
      return const <String>{};
    }
    return csv
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty && _fromString(item) == null)
        .toSet();
  }
}
