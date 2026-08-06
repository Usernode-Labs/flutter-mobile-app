import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart side of the `com.usernode.app/home_shortcuts` platform channel.
///
/// Android implements pinned homescreen shortcuts
/// (`HomeShortcutsHandler.kt`); iOS mirrors the pinned-dapps registry into
/// the App Group container consumed by the `UsernodeWidgets` WidgetKit
/// extension (`HomeShortcutsChannel.swift`).
///
/// All methods fail soft: on unexpected platform errors (or when running on
/// a platform without a native handler) they return the "unsupported"
/// answer instead of throwing, so the webview bridge can always resolve its
/// JS promise.
class HomeShortcutsChannel {
  static const MethodChannel _channel =
      MethodChannel('com.usernode.app/home_shortcuts');

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Android: whether the current launcher supports pin-shortcut requests.
  static Future<bool> isPinShortcutSupported() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isPinShortcutSupported') ??
          false;
    } catch (e) {
      debugPrint('[HomeShortcuts] isPinShortcutSupported failed: $e');
      return false;
    }
  }

  /// Android: asks the launcher to pin a shortcut. Returns true when the
  /// request was handed to the launcher (the user still confirms there).
  static Future<bool> requestPinShortcut({
    required String id,
    required String label,
    required String deepLink,
    Uint8List? iconBytes,
  }) async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPinShortcut', {
            'id': id,
            'label': label,
            'deepLink': deepLink,
            'iconBytes': iconBytes,
          }) ??
          false;
    } catch (e) {
      debugPrint('[HomeShortcuts] requestPinShortcut failed: $e');
      return false;
    }
  }

  /// iOS: writes the pinned-dapps JSON into the App Group defaults and
  /// reloads the widget timelines.
  static Future<bool> syncPinnedDapps(String json) async {
    if (!isIOS) return false;
    try {
      return await _channel
              .invokeMethod<bool>('syncPinnedDapps', {'json': json}) ??
          false;
    } catch (e) {
      debugPrint('[HomeShortcuts] syncPinnedDapps failed: $e');
      return false;
    }
  }

  /// iOS: persists a dapp icon PNG into the App Group container so the
  /// widget extension can render it. With [dark] the PNG lands in the
  /// entry's dark-appearance slot (`<id>.dark.png`) instead of the
  /// light/default one (`<id>.png`).
  static Future<bool> saveWidgetIcon(
    String id,
    Uint8List bytes, {
    bool dark = false,
  }) async {
    if (!isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('saveWidgetIcon', {
            'id': id,
            'bytes': bytes,
            'dark': dark,
          }) ??
          false;
    } catch (e) {
      debugPrint('[HomeShortcuts] saveWidgetIcon failed: $e');
      return false;
    }
  }

  /// iOS: removes a dapp's icon PNGs from the App Group container. By
  /// default clears BOTH appearance slots — the unpin path, so the store
  /// doesn't leak files (and so a later re-pin of the same URL — which
  /// reuses the deterministic id — can't resurrect a stale icon). With
  /// [darkOnly] it clears just the dark slot, reverting the entry to
  /// single-asset. No-op off iOS.
  static Future<bool> deleteWidgetIcon(String id,
      {bool darkOnly = false}) async {
    if (!isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('deleteWidgetIcon', {
            'id': id,
            'dark': darkOnly,
          }) ??
          false;
    } catch (e) {
      debugPrint('[HomeShortcuts] deleteWidgetIcon failed: $e');
      return false;
    }
  }

  /// iOS: ids that currently have an icon PNG in the App Group store, split
  /// by appearance slot. The native side returns filename stems — a bare id
  /// for the light asset, `<id>.dark` for the dark one — and this splits
  /// them. Lets callers spot registry entries whose icon (or dark icon) was
  /// never saved (e.g. pinned by an older page that sent no icon) so they
  /// can re-send it.
  static Future<({Set<String> light, Set<String> dark})>
      listWidgetIconIds() async {
    if (!isIOS) return (light: const <String>{}, dark: const <String>{});
    try {
      final stems = await _channel.invokeMethod<List<Object?>>(
        'listWidgetIconIds',
      );
      final light = <String>{};
      final dark = <String>{};
      for (final v in stems ?? const <Object?>[]) {
        final stem = v.toString();
        if (stem.endsWith('.dark')) {
          dark.add(stem.substring(0, stem.length - '.dark'.length));
        } else {
          light.add(stem);
        }
      }
      return (light: light, dark: dark);
    } catch (e) {
      debugPrint('[HomeShortcuts] listWidgetIconIds failed: $e');
      return (light: const <String>{}, dark: const <String>{});
    }
  }

  /// iOS: whether the Usernode dApps widget is currently on the homescreen.
  static Future<bool> isWidgetInstalled() async {
    if (!isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isWidgetInstalled') ?? false;
    } catch (e) {
      debugPrint('[HomeShortcuts] isWidgetInstalled failed: $e');
      return false;
    }
  }
}
