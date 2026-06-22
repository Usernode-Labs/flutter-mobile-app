import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/providers/top_status_node_status_provider.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_notification_routing.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/providers/activity_providers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart'
    show formatPoints;
import 'package:crypto_mobile_app/features/dapps/application/dapp_notification_web_route.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String? _handledMockNotificationRequest;
  String? _handledOpenRecordRequest;

  @override
  Widget build(BuildContext context) {
    _handleDebugMockNotificationQuery(context);

    final l10n = AppLocalizations.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final recordsAsync = ref.watch(activityControllerProvider);
    final points =
        ref.watch(
          breakdownProvider.select((state) => state.valueOrNull?.totalPoints),
        ) ??
        ref.watch(
          rankingProvider.select((state) => state.valueOrNull?.totalPoints),
        );
    final profileLabel = points != null ? '${formatPoints(points)} pts' : null;
    final nodeStatus = ref.watch(topStatusNodeStatusProvider);

    return Scaffold(
      // No backgroundColor override → DS scaffold grey (surface), matching the
      // Challenges, Wallet, and dApps tab roots. SafeArea/top inset is owned by
      // TopStatusAppBar.large; adding one here would double-inset the header.
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(activityControllerProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            TopStatusAppBar.large(
              title: l10n.activityTitle,
              profileLabel: profileLabel,
              nodeStatus: nodeStatus,
              onProfilePressed: () => context.push(AppRoutes.profile),
              onNodePressed: () => context.push(AppRoutes.mainNode),
            ),
            ...recordsAsync.when(
              loading: () => [
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: FullPageLoadingState(),
                ),
              ],
              error: (error, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: FullPageErrorState(
                    message: l10n.activityLoadError,
                    detail: '$error',
                    onRetry: () {
                      ref.invalidate(activityControllerProvider);
                    },
                  ),
                ),
              ],
              data: (records) {
                final visible = [
                  for (final record in records)
                    if (!record.archived) record,
                ];
                _handleOpenRecordQuery(context, visible);
                if (visible.isEmpty) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Symbols.notifications_sharp,
                        title: l10n.activityEmptyTitle,
                        subtitle: l10n.activityEmptyBody,
                      ),
                    ),
                  ];
                }

                return [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      spacing.space16,
                      0,
                      spacing.space16,
                      spacing.space32,
                    ),
                    sliver: SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: spacing.space12),
                      itemBuilder: (context, index) {
                        final record = visible[index];
                        return _ActivityCard(
                          record: record,
                          onTap: () async {
                            await ref
                                .read(activityControllerProvider.notifier)
                                .markRead(record.id);
                            if (!context.mounted) return;
                            _openRecord(context, record);
                          },
                        );
                      },
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleDebugMockNotificationQuery(BuildContext context) {
    if (!kDebugMode) return;

    final Uri uri;
    try {
      uri = GoRouterState.of(context).uri;
    } catch (_) {
      return;
    }

    final key = uri.queryParameters['mockNotification'];
    if (key == null || key.isEmpty) return;

    final nonce = uri.queryParameters['nonce'] ?? '';
    final requestId = '$key:$nonce';
    if (_handledMockNotificationRequest == requestId) return;
    _handledMockNotificationRequest = requestId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(activityControllerProvider.notifier)
          .injectMockNotificationScenario(key);
    });
  }

  void _handleOpenRecordQuery(
    BuildContext context,
    List<ActivityRecord> records,
  ) {
    final Uri uri;
    try {
      uri = GoRouterState.of(context).uri;
    } catch (_) {
      return;
    }

    final recordId = uri.queryParameters['openRecord']?.trim();
    if (recordId == null || recordId.isEmpty) return;
    if (_handledOpenRecordRequest == recordId) return;

    ActivityRecord? record;
    for (final candidate in records) {
      if (candidate.id == recordId) {
        record = candidate;
        break;
      }
    }
    if (record == null) return;

    final targetRecord = record;
    _handledOpenRecordRequest = recordId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(activityControllerProvider.notifier)
          .markRead(targetRecord.id);
      if (!mounted || !context.mounted) return;
      _openRecord(context, targetRecord);
    });
  }

  void _openRecord(BuildContext context, ActivityRecord record) {
    final route = resolveActivityRecordRoute(record);
    if (route != activityNotificationFallbackRoute) {
      if (_openDappRecordSource(context, record, route)) {
        return;
      }
      context.push(route);
    }
  }

  bool _openDappRecordSource(
    BuildContext context,
    ActivityRecord record,
    String route,
  ) {
    if (record.source != ActivitySource.dapp) return false;

    if (route == AppRoutes.dapps) {
      return _openDappsSource(context, record);
    }

    final slug = _dappSlugFromNativeRoute(route);
    if (slug == null) return false;

    final dapp = ref.read(dappBySlugProvider(slug));
    if (dapp == null) return false;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DappWebViewScreen(
          url: _dappNotificationUrl(dapp.url, record),
          name: dapp.name,
          dappSlug: dapp.slug,
        ),
      ),
    );
    return true;
  }

  bool _openDappsSource(BuildContext context, ActivityRecord record) {
    final url = AppConfig.dappsTabUrl.trim();
    if (url.isEmpty) return false;

    final webRoute = _webRoute(record);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DappWebViewScreen(
          url: _dappNotificationUrl(url, record),
          name: _dappsSourceTitle(url, record),
          dappSlug: dappSlugFromNotificationWebRoute(webRoute),
        ),
      ),
    );
    return true;
  }

  static String _dappNotificationUrl(String baseUrl, ActivityRecord record) {
    return resolveDappNotificationWebUrl(
      baseUrl: baseUrl,
      webRoute: _webRoute(record),
    )!;
  }

  static String? _webRoute(ActivityRecord record) {
    final value = record.payloadJson['webRoute'];
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _dappSlugFromNativeRoute(String route) {
    final match = RegExp(r'^/dapps/([a-z0-9-]+)$').firstMatch(route);
    return match?.group(1);
  }

  static String _dappsSourceTitle(String url, ActivityRecord record) {
    final dappName = record.payloadJson['dappName']?.toString().trim();
    if (dappName != null && dappName.isNotEmpty) return dappName;
    final configured = AppConfig.dappsTabName.trim();
    if (configured.isNotEmpty) return configured;
    final uri = Uri.tryParse(url);
    return uri?.host.isNotEmpty == true ? uri!.host : 'dApps';
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.record, required this.onTap});

  final ActivityRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final spacing = theme.extension<AppSpacing>()!;
    final semantic = theme.extension<AppSemanticColors>()!;
    final foreground = record.pinned
        ? semantic.warning.onColorContainer
        : colors.onSurface;
    final secondaryForeground = record.pinned
        ? semantic.warning.onColorContainer.withValues(alpha: 0.76)
        : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      container: true,
      label: _semanticLabel(record, l10n),
      onTap: onTap,
      child: ExcludeSemantics(
        child: AppCard(
          color: record.pinned
              ? semantic.warning.colorContainer
              : colors.surfaceContainerLowest,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.space4,
            children: [
              _ActivityHeader(
                target: _targetName(record),
                timestamp: _relativeTime(record.createdAt, l10n),
                unread: record.unread,
                color: secondaryForeground,
                unreadColor: foreground,
              ),
              _ActivityTitle(
                title: record.title,
                emphasized: record.unread || record.pinned,
                color: foreground,
              ),
              Text(
                record.body,
                style: textTheme.bodyMedium?.copyWith(
                  color: secondaryForeground,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _semanticLabel(ActivityRecord record, AppLocalizations l10n) {
    final parts = [
      if (record.unread) l10n.activitySemanticUnread,
      if (record.pinned) l10n.activitySemanticNeedsAttention,
      _contextLine(record, l10n),
      record.title,
      record.body,
    ];
    return parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join('. ');
  }

  static String _contextLine(ActivityRecord record, AppLocalizations l10n) {
    return '${_targetName(record)} · ${_relativeTime(record.createdAt, l10n)}';
  }

  static String _targetName(ActivityRecord record) {
    final dappName = record.payloadJson['dappName']?.toString().trim();
    if (dappName != null && dappName.isNotEmpty) {
      return _displayDappName(dappName);
    }

    return switch (record.targetRoute) {
      AppRoutes.profileSettings => 'Usernode settings',
      '/main/node' => 'Node status',
      '/challenges' => 'Challenges',
      _ => record.category.routeHint,
    };
  }

  static String _displayDappName(String value) {
    final host = Uri.tryParse('https://$value')?.host ?? '';
    if (!host.contains('.')) return value;

    final base = host
        .replaceFirst(RegExp(r'\.usernodelabs\.org$'), '')
        .replaceFirst(RegExp(r'\.social-vibecoding$'), '');
    return _titleCase(base.replaceAll('-', ' '));
  }

  static String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  static String _relativeTime(DateTime createdAt, AppLocalizations l10n) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return l10n.timeCompactNow;
    if (diff.inMinutes < 60) return l10n.timeCompactMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeCompactHoursAgo(diff.inHours);
    return l10n.timeCompactDaysAgo(diff.inDays);
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({
    required this.target,
    required this.timestamp,
    required this.unread,
    required this.color,
    required this.unreadColor,
  });

  final String target;
  final String timestamp;
  final bool unread;
  final Color color;
  final Color unreadColor;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: color);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            target,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: spacing.space12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timestamp,
              style: style?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (unread) ...[
              SizedBox(width: spacing.space8),
              _UnreadDot(color: unreadColor),
            ],
          ],
        ),
      ],
    );
  }
}

class _ActivityTitle extends StatelessWidget {
  const _ActivityTitle({
    required this.title,
    required this.emphasized,
    required this.color,
  });

  final String title;
  final bool emphasized;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = (textTheme.titleMedium ?? const TextStyle()).copyWith(
      color: color,
      fontWeight: emphasized ? FontWeight.w700 : null,
    );

    return Text(
      title,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Container(
      width: spacing.space8,
      height: spacing.space8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
