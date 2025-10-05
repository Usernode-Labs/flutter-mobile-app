import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

class NodePeersScreen extends StatelessWidget {
  final List<RpcPeerInfo> peers;
  const NodePeersScreen({super.key, required this.peers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const AppAppBar(
        title: 'Node Peers',
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: peers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final p = peers[i];
            final status = p.connectionStatus.toString().split('.').last;
            final statusColor = _statusColor(theme, p.connectionStatus);
            final details = p.connectingDetails;
            final incoming = p.incoming ? 'incoming' : 'outgoing';
            final peerIdRaw = p.peerId.toString();
            final idShort = _shortenMid(peerIdRaw);
            final ipOnly = _peerIpOnly(p);
            final timeStr = _formatTimeAgo(p.time);
            final titleText = ipOnly ?? '(no address)';

            return Material(
              color: theme.colorScheme.surface,
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  foregroundColor: statusColor,
                  child: const Icon(Icons.hub),
                ),
                title: Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            label: Text(status),
                            backgroundColor:
                                statusColor.withValues(alpha: 0.12),
                            labelStyle: theme.textTheme.bodySmall
                                ?.copyWith(color: statusColor),
                            visualDensity:
                                const VisualDensity(horizontal: -4, vertical: -4),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: incoming == 'incoming'
                                ? 'Incoming'
                                : 'Outgoing',
                            child: Icon(
                              incoming == 'incoming'
                                  ? Icons.call_received
                                  : Icons.call_made,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (details != null && details.isNotEmpty)
                        Text(
                          details,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        'id: $idShort',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'time: $timeStr',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                dense: false,
              ),
            );
          },
        ),
      ),
    );
  }

  Color _statusColor(ThemeData theme, PeerConnectionStatus s) {
    switch (s) {
      case PeerConnectionStatus.connected:
        return Colors.green;
      case PeerConnectionStatus.connecting:
        return Colors.amber;
      case PeerConnectionStatus.disconnected:
        return Colors.red;
      case PeerConnectionStatus.disconnecting:
        return Colors.orange;
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
    if (ipv6Raw != null && ipv6Raw.group(0)!.contains(':')) return ipv6Raw.group(0);
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
