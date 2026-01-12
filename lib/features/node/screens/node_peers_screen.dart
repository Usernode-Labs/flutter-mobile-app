import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/core/config/theme.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';

class NodePeersScreen extends StatelessWidget {
  final List<RpcPeerInfo> peers;
  const NodePeersScreen({super.key, required this.peers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Summary header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Text(
                l10n.nodePeersSummary(peers.length.toString(),
                    connected.toString(), connecting.toString()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Peer list
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: sortedPeers.length,
                separatorBuilder: (_, __) => Divider(
                  height: 8,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                itemBuilder: (_, i) {
                  final p = sortedPeers[i];
                  final status = p.connectionStatus.toString().split('.').last;
                  final statusColor = _statusColor(theme, p.connectionStatus);
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
                  final directionIcon =
                      p.incoming ? Icons.arrow_downward : Icons.arrow_upward;

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.hub_outlined,
                          color: colorScheme.onSurface, size: 24),
                    ),
                    title: Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Direction icon badge
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: directionColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color:
                                        directionColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  directionIcon,
                                  size: 16,
                                  color: directionColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Peer ID or details
                              Expanded(
                                child: Text(
                                  details != null && details.isNotEmpty
                                      ? details
                                      : 'id: $idShort',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Best tip info
                          Row(
                            children: [
                              Icon(
                                Icons.bar_chart,
                                size: 10,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Height: ${p.bestTipHeight?.toString() ?? 'N/A'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.schedule,
                                size: 10,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Slot: ${p.bestTipGlobalSlot?.toString() ?? 'N/A'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeStr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w400,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    dense: true,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ThemeData theme, PeerConnectionStatus s) {
    final colorScheme = theme.colorScheme;
    switch (s) {
      case PeerConnectionStatus.connected:
        return colorScheme.tertiary; // Green
      case PeerConnectionStatus.connecting:
        return MaterialTheme.warningColor; // Orange
      case PeerConnectionStatus.disconnected:
        return colorScheme.error; // Red
      case PeerConnectionStatus.disconnecting:
        return MaterialTheme.accentYellow; // Amber
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
