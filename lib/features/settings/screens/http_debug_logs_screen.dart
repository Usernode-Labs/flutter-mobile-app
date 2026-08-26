import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/providers/log_share_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/services/http_debug_log_store.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

/// Viewer for HTTP traffic captured while Debug Mode is on.
///
/// Reads the in-memory [HttpDebugLogStore] and rebuilds live as requests
/// arrive (the store is a [ChangeNotifier]). Entries are already redacted and
/// truncated. The app bar offers copy-all-to-clipboard and clear.
class HttpDebugLogsScreen extends ConsumerStatefulWidget {
  const HttpDebugLogsScreen({super.key});

  @override
  ConsumerState<HttpDebugLogsScreen> createState() =>
      _HttpDebugLogsScreenState();
}

class _HttpDebugLogsScreenState extends ConsumerState<HttpDebugLogsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reflect any filter already in effect — it persists across screen opens
    // and also drives copy/share.
    _searchController.text = ref.read(httpLogFilterProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Case-insensitive substring match on the request URL.
  List<HttpLogEntry> _applyFilter(List<HttpLogEntry> entries, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries
        .where((e) => e.url.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(httpDebugLogStoreProvider);
    final query = ref.watch(httpLogFilterProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    // Surface a one-off message when the backend asks us to stop sharing.
    ref.listen(logShareControllerProvider, (prev, next) {
      if (next.stoppedByServer && prev?.stoppedByServer != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.httpLogsShareStopped)),
        );
      }
    });

    final hasQuery = query.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.httpLogsTitle),
        actions: [
          IconButton(
            icon: const Icon(Symbols.content_copy_sharp),
            tooltip: l10n.httpLogsCopy,
            onPressed: () async {
              // Copy the currently-visible (filtered) entries.
              final visible = _applyFilter(store.entries, query);
              if (visible.isEmpty) return;
              final text = visible.map((e) => e.toLogText()).join('\n');
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.httpLogsCopied)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Symbols.delete_sharp),
            tooltip: l10n.httpLogsClear,
            onPressed: store.clear,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.space16,
              0,
              spacing.space16,
              spacing.space8,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  ref.read(httpLogFilterProvider.notifier).state = value,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.httpLogsFilterHint,
                prefixIcon: const Icon(Symbols.search_sharp),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Symbols.close_sharp),
                        tooltip: l10n.httpLogsClear,
                        onPressed: () {
                          _searchController.clear();
                          ref.read(httpLogFilterProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final all = store.entries;
            final entries = _applyFilter(all, query);
            if (entries.isEmpty) {
              return _EmptyState(
                message: hasQuery ? l10n.httpLogsNoMatches : l10n.httpLogsEmpty,
              );
            }
            return Column(
              children: [
                if (hasQuery)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.space16,
                      vertical: spacing.space8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.httpLogsFilterCount(entries.length, all.length),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _HttpLogTile(entry: entries[i]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const _ShareLogsBar(),
    );
  }
}

/// Bottom action bar that toggles periodic log sharing with the team.
///
/// Disabled until a participant ID exists. While active it shows a caption and
/// a stop button; the backend can also end the session (see [LogShareState]),
/// after which this returns to the idle "share" affordance.
class _ShareLogsBar extends ConsumerWidget {
  const _ShareLogsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);

    final shareState = ref.watch(logShareControllerProvider);
    final participantId = ref
        .watch(identityProvider.select((identity) => identity.participantId));
    final controller = ref.read(logShareControllerProvider.notifier);

    final Widget child;
    if (shareState.isSharing) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.httpLogsSharing,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing.space8),
          SizedBox(
            width: double.infinity,
            child: Button(
              label: l10n.httpLogsStopSharing,
              leadingIcon: const Icon(Symbols.stop_circle_sharp),
              onTap: controller.stop,
              variant: ButtonVariant.outlined,
            ),
          ),
        ],
      );
    } else {
      final canShare = participantId != null;
      child = Tooltip(
        message: canShare ? '' : l10n.httpLogsShareNoParticipant,
        child: SizedBox(
          width: double.infinity,
          child: Button(
            label: l10n.httpLogsShare,
            leadingIcon: const Icon(Symbols.upload_sharp),
            onTap: canShare ? () => controller.start(participantId) : null,
            variant: ButtonVariant.primary,
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: child,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.cloud_off_sharp,
              size: spacing.space48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: spacing.space16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HttpLogTile extends StatelessWidget {
  const _HttpLogTile({required this.entry});

  final HttpLogEntry entry;

  static const _monoStyle =
      TextStyle(fontFamily: kMonoFontFamily, fontSize: 12);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final semantic = theme.extension<AppSemanticColors>()!;

    final statusColor =
        entry.isError ? theme.colorScheme.error : semantic.success.color;
    final statusLabel = entry.statusCode?.toString() ?? 'ERR';
    final uri = Uri.tryParse(entry.url);
    final pathLabel = uri == null
        ? entry.url
        : '${uri.host}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';

    return ExpansionTile(
      tilePadding: EdgeInsets.symmetric(horizontal: spacing.space16),
      childrenPadding: EdgeInsets.fromLTRB(
        spacing.space16,
        0,
        spacing.space16,
        spacing.space16,
      ),
      leading: Text(
        statusLabel,
        style: theme.textTheme.labelLarge?.copyWith(
          color: statusColor,
          fontFamily: kMonoFontFamily,
          fontWeight: FontWeight.bold,
        ),
      ),
      title: Text(
        '${entry.method}  $pathLabel',
        style: _monoStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_formatTime(entry.timestamp)}'
        '${entry.durationMs != null ? '  ·  ${entry.durationMs}ms' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        SelectableText(entry.toLogText(), style: _monoStyle),
      ],
    );
  }

  String _formatTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}
