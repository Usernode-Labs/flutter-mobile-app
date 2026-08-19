part of '../dapp_webview_screen.dart';

bool _isLocalDevHost(String host) =>
    host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';

/// Accepts https URLs, plus http for local development hosts only.
///
/// Deliberately NOT `uri.isAbsolute`: that is false for any URL carrying
/// a `#fragment` (RFC 3986 "absolute URI"), which rejected legitimate
/// SPA deep links like `https://host/#app/slug`. Scheme + host checks
/// below are what we actually need.
Uri? _parseShortcutUrl(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme == 'https') return uri;
  if (uri.scheme == 'http' && _isLocalDevHost(uri.host)) return uri;
  return null;
}

/// Inline `data:image/*;base64,...` icons. The dapps home renders its
/// emoji/letter tiles to a canvas PNG so the homescreen widget shows
/// the exact same tile — no server round-trip, same size cap as
/// downloads.
Uint8List? _decodeDataUriIcon(Object? raw) {
  if (raw is! String || !raw.startsWith('data:image/')) return null;
  try {
    final bytes = UriData.parse(raw).contentAsBytes();
    if (bytes.isEmpty || bytes.length > _maxShortcutIconBytes) return null;
    return bytes;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _downloadShortcutIcon(Uri iconUri) async {
  final client = http.Client();
  try {
    // followRedirects: false so a 3xx can't bounce us to a loopback/internal
    // host that _parseShortcutUrl already rejected for the original URL
    // (SSRF). Anything other than a direct 200 is treated as a miss.
    final request = http.Request('GET', iconUri)..followRedirects = false;
    final res = await client.send(request).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;

    // Reject up front when the server declares an oversized body, then cap
    // again while streaming so a missing/lying Content-Length can't OOM the
    // device before the post-hoc length check would have run.
    final declaredLength = res.contentLength;
    if (declaredLength != null && declaredLength > _maxShortcutIconBytes) {
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res.stream.timeout(const Duration(seconds: 10))) {
      builder.add(chunk);
      if (builder.length > _maxShortcutIconBytes) return null;
    }
    if (builder.isEmpty) return null;
    return builder.takeBytes();
  } catch (e) {
    debugPrint('[HomeShortcuts] icon download failed: $e');
    return null;
  } finally {
    client.close();
  }
}

const _maxShortcutNameLength = 48;
const _maxShortcutIconBytes = 2 * 1024 * 1024;

/// Homescreen shortcut bridge methods: pin/list/remove/reorder plus
/// the iOS widget sync and install walkthrough. See the section
/// comment inside for the trust model.
mixin _BridgeShortcuts on _DappWebViewScreenStateBase {
  // ── Homescreen shortcuts (bridge) ─────────────────────────────────────
  //
  // `addHomeScreenShortcut` lets a dapp request a device-homescreen entry
  // that reopens the app at `usernode://app/dapps/pinned/<id>`. Android
  // pins a real launcher shortcut; iOS mirrors the pinned registry into the
  // App Group storage consumed by the UsernodeWidgets WidgetKit extension.

  Future<Map<String, dynamic>> _shortcutSupport() async {
    if (HomeShortcutsChannel.isAndroid) {
      final supported = await HomeShortcutsChannel.isPinShortcutSupported();
      return {'mechanism': supported ? 'pinned-shortcut' : 'unsupported'};
    }
    if (HomeShortcutsChannel.isIOS) {
      final installed = await HomeShortcutsChannel.isWidgetInstalled();
      return {'mechanism': 'widget', 'widgetInstalled': installed};
    }
    return {'mechanism': 'unsupported'};
  }

  Future<void> _handleGetHomeScreenShortcutSupport(String id) async {
    await _resolveJsPromise(
      id: id,
      value: await _shortcutSupport(),
      error: null,
    );
  }

  Future<void> _handleAddHomeScreenShortcut(
      String id, Map<String, dynamic> payload) async {
    // Trust gate instead of a confirmation screen: the dapps-tab home
    // (social vibecoding) curates its own "add to widget/homescreen" UX,
    // so requests from it are auto-approved; every other page is denied
    // outright. Shortcuts only deep-link back into this app, so the
    // blast radius of a bad add is a launcher tile — not funds.
    if (!await _guardTrustedShortcutOrigin(id)) return;
    final args = payload['args'];
    if (args is! Map<String, dynamic>) {
      await _resolveJsPromise(id: id, value: null, error: 'Missing args');
      return;
    }

    var name = (args['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      await _resolveJsPromise(id: id, value: null, error: 'name is required');
      return;
    }
    if (name.length > _maxShortcutNameLength) {
      name = name.substring(0, _maxShortcutNameLength);
    }

    final url = _parseShortcutUrl(args['url']);
    if (url == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'url must be a valid https URL',
      );
      return;
    }

    final support = await _shortcutSupport();
    if (support['mechanism'] == 'unsupported') {
      await _resolveJsPromise(
        id: id,
        value: <String, dynamic>{'added': false, ...support},
        error: null,
      );
      return;
    }

    final rawIcon = args['icon_url'];
    Uint8List? iconBytes = _decodeDataUriIcon(rawIcon);
    Uri? iconUri;
    if (iconBytes == null) {
      iconUri = _parseShortcutUrl(rawIcon);
      if (iconUri != null) iconBytes = await _downloadShortcutIcon(iconUri);
    }

    // Optional dark-appearance asset (`icon_url_dark`, additive — see the
    // `homeScreenShortcutDarkIcon` capability). Same accepted shapes and
    // same decode/download path as `icon_url`: data URI or https URL.
    // Absent/null/empty means "single-asset entry" and clears any stored
    // dark slot below, so the page can revert an entry by omitting it.
    final rawIconDark = args['icon_url_dark'];
    final darkIconSupplied =
        rawIconDark is String && rawIconDark.trim().isNotEmpty;
    Uint8List? darkIconBytes;
    if (darkIconSupplied) {
      darkIconBytes = _decodeDataUriIcon(rawIconDark);
      if (darkIconBytes == null) {
        final darkIconUri = _parseShortcutUrl(rawIconDark);
        if (darkIconUri != null) {
          darkIconBytes = await _downloadShortcutIcon(darkIconUri);
        }
      }
    }

    // Re-check the privileged lease after the icon downloads: they are the
    // long awaits during which a navigation can invalidate the realm, and
    // this is the last gate before the registry mutation.
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'addHomeScreenShortcut',
    )) {
      return;
    }
    final pinned = await _providers.read(pinnedDappsProvider.notifier).pin(
          name: name,
          url: url.toString(),
          // Data-URI icons are not persisted in the registry (kilobytes
          // of base64 in prefs for no reader); the PNG lands in the App
          // Group icon store below either way.
          iconUrl: iconUri?.toString() ?? '',
        );
    final deepLink = 'usernode://app${AppRoutes.dappPinnedFor(pinned.id)}';

    if (HomeShortcutsChannel.isAndroid) {
      final requested = await HomeShortcutsChannel.requestPinShortcut(
        id: pinned.id,
        label: pinned.name,
        deepLink: deepLink,
        iconBytes: iconBytes,
      );
      await _resolveJsPromise(
        id: id,
        value: <String, dynamic>{
          'added': requested,
          'mechanism': 'pinned-shortcut',
        },
        error: null,
      );
      return;
    }

    // iOS: mirror the registry into the App Group so the widget extension
    // can render it, then walk the user through adding the widget if it
    // isn't on the homescreen yet.
    if (iconBytes != null) {
      await HomeShortcutsChannel.saveWidgetIcon(pinned.id, iconBytes);
    }
    if (darkIconBytes != null) {
      await HomeShortcutsChannel.saveWidgetIcon(
        pinned.id,
        darkIconBytes,
        dark: true,
      );
    } else if (!darkIconSupplied) {
      // Re-add without `icon_url_dark`: revert to single-asset. When the
      // field WAS supplied but the fetch failed, keep whatever dark asset
      // is already stored — a transient network miss must not destroy a
      // good icon (`has_icon_dark` keeps reporting the stored state, so
      // the page can still heal it later).
      await HomeShortcutsChannel.deleteWidgetIcon(pinned.id, darkOnly: true);
    }
    // Report the real sync result rather than a hardcoded true: if the App
    // Group is unavailable the native side returns false and nothing reaches
    // the widget, so a caller that trusted `added: true` would show the dapp
    // as pinned over an empty widget.
    final added = await _syncPinnedToWidget();
    // `widgetInstalled` was already fetched by `_shortcutSupport()` above
    // (whether the widget is on the homescreen doesn't change from pinning),
    // so reuse it instead of a second platform round-trip.
    final widgetInstalled = support['widgetInstalled'] == true;
    // silent: background refresh (icon heal) — never interrupt with the
    // add-the-widget walkthrough.
    final silent = args['silent'] == true;
    // Resolve the JS promise before showing the (modal, pop-to-dismiss)
    // walkthrough — otherwise the page's `await addHomeScreenShortcut(...)`
    // stays pending for as long as the user leaves the walkthrough open.
    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{
        'added': added,
        'mechanism': 'widget',
        'widgetInstalled': widgetInstalled,
      },
      error: null,
    );
    if (added && !widgetInstalled && !silent && mounted) {
      await _showWidgetInstructions(name);
    }
  }

  /// Mirrors the pinned registry (in registry order — the widget grid
  /// renders the synced JSON array as-is) into the App Group defaults and
  /// reloads the widget timelines. Returns whether the native write
  /// succeeded; treats non-iOS as a successful no-op.
  Future<bool> _syncPinnedToWidget() async {
    if (!HomeShortcutsChannel.isIOS) return true;
    final dapps = await _providers.read(pinnedDappsProvider.future);
    return HomeShortcutsChannel.syncPinnedDapps(jsonEncode([
      for (final d in dapps)
        {
          'id': d.id,
          'name': d.name,
          'deepLink': 'usernode://app${AppRoutes.dappPinnedFor(d.id)}',
          'pinnedAtMs': d.pinnedAtMs,
        },
    ]));
  }

  /// Registry snapshot for the page: ids, names, urls and pin order. The
  /// url lets the caller match entries back to its own content (e.g. SV
  /// matching `#app/<slug>` deep links to its app cards). This is launcher
  /// metadata the page's own user created; no secrets involved.
  ///
  /// `has_icon` / `has_icon_dark` (iOS only) flag entries whose PNG made it
  /// into the App Group icon store, per appearance slot. Entries pinned
  /// before the page sent icons — or whose icon download failed — report
  /// false, and the dapps home heals them by re-calling
  /// addHomeScreenShortcut (re-pinning is idempotent: same URL, same id).
  /// `has_icon_dark` false is also the normal state for entries pinned
  /// before dark icons existed — that's how the page tells "needs both
  /// faces re-sent" from "already dual-asset" without re-sending the grid.
  Future<void> _handleGetHomeScreenShortcuts(String id) async {
    if (!await _guardTrustedShortcutOrigin(id)) return;
    // These three reads are independent — fetch them concurrently rather than
    // paying a prefs read plus two platform round-trips in series.
    final (dapps, iconIds, support) = await (
      _providers.read(pinnedDappsProvider.future),
      HomeShortcutsChannel.listWidgetIconIds(),
      _shortcutSupport(),
    ).wait;
    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{
        ...support,
        'items': [
          for (final d in dapps)
            {
              'id': d.id,
              'name': d.name,
              'url': d.url,
              'pinnedAtMs': d.pinnedAtMs,
              // Off iOS both report true — same convention as `has_icon`
              // always had: "true" means "nothing for the page to heal",
              // and Android's launcher shortcuts have no icon store.
              'has_icon':
                  !HomeShortcutsChannel.isIOS || iconIds.light.contains(d.id),
              'has_icon_dark':
                  !HomeShortcutsChannel.isIOS || iconIds.dark.contains(d.id),
            },
        ],
      },
      error: null,
    );
  }

  /// Removes a pinned entry and re-syncs the iOS widget. No native
  /// confirmation: launcher entries are low-stakes and the calling UI
  /// (e.g. SV's widget section) puts the control behind a deliberate tap.
  /// On Android this only clears the registry — launchers offer no
  /// programmatic un-pin, so the callers there never expose remove.
  Future<void> _handleRemoveHomeScreenShortcut(
      String id, Map<String, dynamic> payload) async {
    if (!await _guardTrustedShortcutOrigin(id)) return;
    final args = payload['args'];
    final shortcutId =
        args is Map<String, dynamic> ? (args['id'] as String?)?.trim() : null;
    if (shortcutId == null || shortcutId.isEmpty) {
      await _resolveJsPromise(id: id, value: null, error: 'id is required');
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'removeHomeScreenShortcut',
    )) {
      return;
    }
    await _providers.read(pinnedDappsProvider.notifier).unpin(shortcutId);
    // Drop the icon PNG too, otherwise it lingers in the App Group store
    // forever and a later re-pin of the same URL would show the stale image.
    await HomeShortcutsChannel.deleteWidgetIcon(shortcutId);
    await _syncPinnedToWidget();
    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{'removed': true},
      error: null,
    );
  }

  /// Reorders the pinned registry to the given id list and re-syncs the
  /// iOS widget. Unknown ids are ignored and missing ids are appended, so
  /// a stale caller can never drop entries (see PinnedDappsNotifier).
  Future<void> _handleReorderHomeScreenShortcuts(
      String id, Map<String, dynamic> payload) async {
    if (!await _guardTrustedShortcutOrigin(id)) return;
    final args = payload['args'];
    final rawIds = args is Map<String, dynamic> ? args['ids'] : null;
    if (rawIds is! List) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'ids must be a list of shortcut ids',
      );
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'reorderHomeScreenShortcuts',
    )) {
      return;
    }
    final ids = [for (final v in rawIds) v.toString()];
    final updated =
        await _providers.read(pinnedDappsProvider.notifier).reorder(ids);
    await _syncPinnedToWidget();
    await _resolveJsPromise(
      id: id,
      value: <String, dynamic>{
        'order': [for (final d in updated) d.id],
      },
      error: null,
    );
  }

  /// One-time iOS walkthrough shown after a pin when the Usernode widget
  /// isn't on the homescreen yet.
  Future<void> _showWidgetInstructions(String dappName) async {
    if (!mounted) return;

    await Navigator.push<void>(
      context,
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, _, __) {
          final l10n = AppLocalizations.of(ctx);
          final theme = Theme.of(ctx);
          final spacing = theme.extension<AppSpacing>()!;
          final sizing = theme.extension<AppSizing>()!;

          Widget step(int number, String text) {
            return Padding(
              padding: EdgeInsets.only(bottom: spacing.space12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: spacing.space8),
                  Expanded(
                    child: Text(text, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Symbols.close),
              ),
              title: Text(l10n.widgetInstructionsTitle),
              titleSpacing: 0,
            ),
            body: Padding(
              padding: EdgeInsets.all(spacing.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Symbols.widgets,
                    size: sizing.iconDisplay,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(height: spacing.space16),
                  Text(
                    l10n.widgetInstructionsBody(dappName),
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.space24),
                  step(1, l10n.widgetInstructionsStep1),
                  step(2, l10n.widgetInstructionsStep2),
                  step(3, l10n.widgetInstructionsStep3),
                  const Spacer(),
                  Button(
                    label: l10n.widgetInstructionsDone,
                    variant: ButtonVariant.primary,
                    onTap: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            )),
            child: child,
          );
        },
      ),
    );
  }
}
