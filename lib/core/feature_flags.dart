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

  /// Compute enabled set from compile-time env or fallback defaults.
  static Set<AppFeature> _enabled = _loadEnabledFromEnv();

  /// Additional granular feature keys, e.g. 'wallet.send', 'home.bridgeCard'.
  static final Set<String> _tagsEnabled = <String>{};
  static final Set<String> _tagsDisabled = <String>{};

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
        ..addAll(enabledItems);
      _tagsDisabled
        ..clear()
        ..addAll(disabledItems);

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
}
