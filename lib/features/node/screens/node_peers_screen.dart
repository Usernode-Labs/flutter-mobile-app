import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/core/utils/utils.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';

class NodePeersScreen extends StatelessWidget {
  final List<RpcPeerInfo> peers;
  final String? peerId;
  const NodePeersScreen({super.key, required this.peers, this.peerId});

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context);

    // Calculate peer statistics
    int connected = 0;
    int connecting = 0;

    for (final peer in peers) {
      switch (peer.connectionStatus) {
        case PeerConnectionStatus.connected:
          connected++;
          break;
        case PeerConnectionStatus.connecting:
        case PeerConnectionStatus.disconnecting:
          connecting++;
          break;
        case PeerConnectionStatus.disconnected:
          break;
      }
    }

    // Sort peers: Connected first, then Connecting, then Disconnected
    // Within each group, sort by time (most recent first)
    final sortedPeers = List<RpcPeerInfo>.from(peers)
      ..sort((a, b) {
        // Assign priority to each status
        int getPriority(PeerConnectionStatus status) {
          switch (status) {
            case PeerConnectionStatus.connected:
              return 0;
            case PeerConnectionStatus.connecting:
            case PeerConnectionStatus.disconnecting:
              return 1;
            case PeerConnectionStatus.disconnected:
              return 2;
          }
        }

        final priorityA = getPriority(a.connectionStatus);
        final priorityB = getPriority(b.connectionStatus);

        // First compare by status priority
        if (priorityA != priorityB) {
          return priorityA.compareTo(priorityB);
        }

        // If same status, sort by time (most recent first)
        return b.time.compareTo(a.time);
      });

    return Scaffold(
      appBar: AppAppBar(
        title: l10n.nodePeersTitle,
        showNodeStatus: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Summary header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(spacing.space16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.nodePeersSummary(peers.length.toString(),
                        connected.toString(), connecting.toString()),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (peerId != null) ...[
                    SizedBox(height: spacing.space8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Peer ID: ${Utils.shortenID(peerId!, head: 8, tail: 8)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(width: spacing.space4),
                        IconButton(
                          icon: const Icon(Symbols.content_copy_sharp),
                          iconSize: sizing.iconXSmall,
                          color: colorScheme.primary,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: peerId!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.nodePeerIdCopied),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Peer list
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                    spacing.space16, 0, spacing.space16, spacing.space32),
                itemCount: sortedPeers.length,
                separatorBuilder: (_, __) => Divider(
                  height: spacing.space8,
                  thickness: 1,
                  indent: spacing.space16,
                  endIndent: spacing.space16,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                itemBuilder: (_, i) {
                  final p = sortedPeers[i];
                  final status = p.connectionStatus.toString().split('.').last;
                  final statusColor =
                      _statusColor(theme, semantic, p.connectionStatus);
                  final details = p.connectingDetails;

                  // Safely stringify peerId
                  String idShort;
                  try {
                    final peerIdRaw = p.peerId.toString();
                    idShort = _shortenMid(peerIdRaw);
                  } catch (_) {
                    idShort = '(unavailable)';
                  }

                  final ipOnly = _peerIpOnly(p);
                  final timeStr = _formatTimeAgo(p.time);
                  final titleText = ipOnly ?? '(Hidden address)';

                  // Direction badge colors
                  final directionColor =
                      p.incoming ? colorScheme.tertiary : colorScheme.secondary;
                  final directionIcon = p.incoming
                      ? Symbols.arrow_downward_sharp
                      : Symbols.arrow_upward_sharp;

                  return ListTile(
                    leading: const IconBadge(icon: Symbols.hub_sharp),
                    title: Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.only(top: spacing.space4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Direction icon badge
                              Container(
                                padding: EdgeInsets.all(spacing.space4),
                                decoration: BoxDecoration(
                                  color: directionColor.withValues(alpha: 0.15),
                                  borderRadius: radii.borderRadiusXSmall,
                                  border: Border.all(
                                    color:
                                        directionColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  directionIcon,
                                  size: sizing.iconXSmall,
                                  color: directionColor,
                                ),
                              ),
                              SizedBox(width: spacing.space8),
                              // Peer ID or details
                              Expanded(
                                child: Text(
                                  details != null && details.isNotEmpty
                                      ? details
                                      : 'id: $idShort',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: spacing.space4),
                          // Best tip info
                          Row(
                            children: [
                              Icon(
                                Symbols.bar_chart_sharp,
                                size: sizing.iconXSmall,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                              SizedBox(width: spacing.space4),
                              Text(
                                'Height: ${p.bestTipHeight?.toString() ?? 'N/A'}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              SizedBox(width: spacing.space8),
                              Text(
                                '•',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              SizedBox(width: spacing.space8),
                              Icon(
                                Symbols.schedule_sharp,
                                size: sizing.iconXSmall,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                              SizedBox(width: spacing.space4),
                              Text(
                                'Slot: ${p.bestTipGlobalSlot?.toString() ?? 'N/A'}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: spacing.space4),
                          Text(
                            timeStr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: spacing.space8, vertical: spacing.space4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: radii.borderRadiusSmall,
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(
      ThemeData theme, AppSemanticColors semantic, PeerConnectionStatus s) {
    final colorScheme = theme.colorScheme;
    switch (s) {
      case PeerConnectionStatus.connected:
        return colorScheme.tertiary; // Green
      case PeerConnectionStatus.connecting:
        return semantic.warning.color; // Orange
      case PeerConnectionStatus.disconnected:
        return colorScheme.error; // Red
      case PeerConnectionStatus.disconnecting:
        return semantic.warning.color; // Amber
    }
  }

  String? _peerIpOnly(RpcPeerInfo p) {
    final addr = _extractIpOnly(p.address);
    if (addr != null) return addr;
    final det = _extractIpOnly(p.connectingDetails);
    return det;
  }

  String? _extractIpOnly(String? text) {
    if (text == null) return null;
    final s = text.trim();
    if (s.startsWith('/')) {
      final parts = s.split('/').where((e) => e.isNotEmpty).toList();
      for (var i = 0; i < parts.length - 1; i++) {
        final t = parts[i].toLowerCase();
        if (t == 'ip4' || t == 'ip6' || t.startsWith('dns')) {
          return parts[i + 1];
        }
      }
    }
    final ipv6Br = RegExp(r'\[([0-9a-fA-F:]+)\]').firstMatch(s);
    if (ipv6Br != null) return ipv6Br.group(0);
    final ipv6Raw = RegExp(r'\b[0-9a-fA-F:]{2,}\b').firstMatch(s);
    if (ipv6Raw != null && ipv6Raw.group(0)!.contains(':')) {
      return ipv6Raw.group(0);
    }
    final ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})').firstMatch(s);
    if (ipv4 != null) return ipv4.group(1);
    final hostOnly = RegExp(r'^([A-Za-z0-9.-]+)').firstMatch(s)?.group(1);
    return hostOnly;
  }

  String _shortenMid(String s, {int head = 8, int tail = 8}) {
    if (s.length <= head + tail + 1) return s;
    return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
  }

  String _formatUtc(BigInt value) {
    final digits = value.toString().length;
    BigInt ms;
    if (digits >= 19) {
      ms = value ~/ BigInt.from(1000000);
    } else if (digits >= 16) {
      ms = value ~/ BigInt.from(1000);
    } else if (digits >= 13) {
      ms = value;
    } else {
      ms = value * BigInt.from(1000);
    }
    final millis = ms.toInt();
    final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    return dt.toIso8601String();
  }

  String _formatTimeAgo(BigInt value) {
    final iso = _formatUtc(value);
    late final DateTime dt;
    try {
      dt = DateTime.parse(iso).toUtc();
    } catch (_) {
      return 'just now';
    }
    final now = DateTime.now().toUtc();
    final diff = now.difference(dt);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 2) return 'a minute ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 2) return 'an hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 2) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '$weeks week${weeks > 1 ? 's' : ''} ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '$months month${months > 1 ? 's' : ''} ago';
    final years = (diff.inDays / 365).floor();
    return '$years year${years > 1 ? 's' : ''} ago';
  }
}
