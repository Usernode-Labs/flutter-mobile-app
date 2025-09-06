import 'dart:async';
import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/services/rust_backend_service.dart';
import 'package:crypto_mobile_app/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

class NodeStatusScreen extends StatefulWidget {
  const NodeStatusScreen({Key? key}) : super(key: key);

  @override
  State<NodeStatusScreen> createState() => _NodeStatusScreenState();
}

class _NodeStatusScreenState extends State<NodeStatusScreen>
    with SingleTickerProviderStateMixin {
  bool _refreshing = false;
  String? _error;
  int? _peerCount;
  List<RpcPeerInfo> _peers = const [];
  int? _blockHeight;
  int? _mempoolCount;
  int? _evaluatedSlots;
  int? _discoveredSlots;

  late final TabController _tabController;
  Timer? _autoTimer;
  Timer? _secondsTimer;
  DateTime? _lastChecked;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
    // Periodic auto-refresh every 8 seconds while this screen is alive.
    _autoTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_refreshing) {
        _refresh();
      }
    });
    // Ticker to update the "checked X seconds ago" counter
    _secondsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _error = null; // keep content visible; show error inline
    });
    try {
      Log.d('NODE', 'Fetching status');
      final status = await RustBackendService.instance.getStatus();
      if (!mounted) return;
      setState(() {
        _peers = status?.peers ?? const [];
        _peerCount = _peers.length;
        // TODO: Map real fields once exposed by RPC (placeholders for now)
        _blockHeight = null;
        _mempoolCount = null;
        _evaluatedSlots = null;
        _discoveredSlots = null;
        _lastChecked = DateTime.now();
      });
    } catch (e, st) {
      Log.e('NODE', 'getStatus failed', e, st);
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final backendId = RustBackendService.instance.instanceId;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Icon(Icons.hub, size: 28),
                const SizedBox(width: 8),
                Text(l10n.nodeStatus, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Row(children: [
                  IconButton(
                    tooltip: l10n.refresh,
                    icon: const Icon(Icons.refresh),
                    onPressed: _refresh,
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _refreshing
                        ? const SizedBox(
                            key: ValueKey('spin'),
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const SizedBox.shrink(key: ValueKey('idle')),
                  ),
                ])
              ],
            ),
            const SizedBox(height: 6),
            if (_lastChecked != null)
              Text(
                l10n.checkedAgoSeconds(_secondsSinceCheck().toString()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            const SizedBox(height: 12),
            if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.nodeStatusError, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 6),
                  Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                ],
              )
            ,
            // Always keep content visible; show placeholders when data is null
            ...[
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (backendId != null && backendId.isNotEmpty) ...[
                        _StatusItem(label: 'Backend ID', value: backendId),
                        const SizedBox(height: 16),
                      ],
                      _StatusItem(label: l10n.currentBlockHeightLabel, value: _fmtInt(_blockHeight)),
                      const SizedBox(height: 16),
                      _StatusItem(label: l10n.nodeStatusLabel, value: _statusText(l10n)),
                      const SizedBox(height: 16),
                      // Peers with icon to open details
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _StatusItem(
                              label: l10n.peersLabel,
                              value: (_peerCount ?? 0).toString(),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Show peers',
                            icon: const Icon(Icons.people_alt_outlined),
                            onPressed: _peers.isEmpty ? null : _showPeersSheet,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _StatusItem(label: l10n.mempoolLabel, value: l10n.transactionsSuffix((_mempoolCount ?? 0).toString())),
                      const SizedBox(height: 16),
                      _StatusItem(label: l10n.evaluatedDiscoveredLabel, value: _evalDiscovered()),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tabs + Slots
              Card(
                child: SizedBox(
                  height: 260,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: Theme.of(context).colorScheme.primary,
                        tabs: [
                          Tab(text: l10n.upcoming),
                          Tab(text: l10n.pastSlots),
                        ],
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                _SlotItem(
                                  icon: Icons.schedule,
                                  title: l10n.scheduledSlot,
                                  subtitle: l10n.inTime('1h 5m'),
                                  iconColor: Colors.purple,
                                ),
                              ],
                            ),
                            ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                _SlotItem(
                                  icon: Icons.search,
                                  title: l10n.discoveredSlot('112'),
                                  subtitle: l10n.inTime('2h 5d'),
                                  iconColor: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                _SlotItem(
                                  icon: Icons.search,
                                  title: l10n.discoveredSlot('113'),
                                  subtitle: l10n.inTime('2h 5d'),
                                  iconColor: Colors.grey,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPeersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Container(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people_alt_outlined, color: theme.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Connected peers (${_peers.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: theme.colorScheme.onPrimaryContainer),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      itemCount: _peers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final p = _peers[i];
                        final status = p.connectionStatus.toString().split('.').last;
                        final statusColor = _statusColor(theme, p.connectionStatus);
                        final addr = p.address ?? '(no address)';
                        final details = p.connectingDetails;
                        final incoming = p.incoming ? 'incoming' : 'outgoing';
                        final peerIdRaw = p.peerId.toString();
                        final idOnly = _extractPeerId(peerIdRaw);
                        final idShort = idOnly != null ? _shortenMid(idOnly) : _shortenMid(peerIdRaw);
                        final ipPort = _peerIp(p) ?? _extractIpPort(peerIdRaw);
                        final time = p.time.toString();
                        return Material(
                          color: theme.colorScheme.surface,
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            tileColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.12),
                              foregroundColor: statusColor,
                              child: const Icon(Icons.hub),
                            ),
                            title: Text(
                              addr,
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
                                        backgroundColor: statusColor.withOpacity(0.12),
                                        labelStyle: theme.textTheme.bodySmall?.copyWith(color: statusColor),
                                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        incoming,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
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
                                  if (ipPort != null)
                                    Text(
                                      'ip: $ipPort',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  Text(
                                    'time: $time',
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(ThemeData theme, PeerConnectionStatus s) {
    switch (s) {
      case PeerConnectionStatus.connected:
        return theme.colorScheme.primary;
      case PeerConnectionStatus.connecting:
        return theme.colorScheme.tertiary;
      case PeerConnectionStatus.disconnected:
        return theme.colorScheme.outline;
      case PeerConnectionStatus.disconnecting:
        return theme.colorScheme.error;
    }
  }

  String? _extractPeerId(String raw) {
    String cleaned = raw.trim();
    // Remove wrappers like "PeerId(...)" or braces
    cleaned = cleaned.replaceAll(RegExp(r'^PeerId\s*[({]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[)}]$'), '');
    // Format like "<id>@..."
    if (cleaned.contains('@')) {
      return cleaned.split('@').first;
    }
    // key-value style
    final idKV = RegExp(r'id\s*[:=]\s*([^,\s}]+)').firstMatch(cleaned);
    if (idKV != null) return idKV.group(1);
    // fallback: longest token
    final tokens = cleaned.split(RegExp(r'[^A-Za-z0-9_-]+')).where((t) => t.isNotEmpty).toList();
    tokens.removeWhere((t) => t.toLowerCase() == 'peerid');
    tokens.sort((a, b) => b.length.compareTo(a.length));
    return tokens.isNotEmpty ? tokens.first : null;
  }

  String? _peerIp(RpcPeerInfo p) {
    // Prefer address field, then connectingDetails
    final addr = _extractIpPort(p.address);
    if (addr != null) return addr;
    final det = _extractIpPort(p.connectingDetails);
    return det;
  }

  String? _extractIpPort(String? text) {
    if (text == null) return null;
    final s = text.trim();
    // IPv6 in brackets, include optional port
    final ipv6 = RegExp(r'\[([0-9a-fA-F:]+)\](?::\d+)?').firstMatch(s);
    if (ipv6 != null) return ipv6.group(0);
    // IPv4 with optional port
    final ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})(?::\d+)?').firstMatch(s);
    if (ipv4 != null) return ipv4.group(0);
    // Fallback: hostname:port
    final host = RegExp(r'([A-Za-z0-9.-]+(?::\d+)?)').firstMatch(s)?.group(0);
    return host;
  }

  String _shortenMid(String s, {int head = 6, int tail = 6}) {
    if (s.length <= head + tail + 1) return s;
    return s.substring(0, head) + '…' + s.substring(s.length - tail);
  }

  String _fmtInt(int? v) => v == null ? 'N/A' : v.toString();
  String _statusText(AppLocalizations l10n) => l10n.inTime('5m');
  String _evalDiscovered() {
    final a = _evaluatedSlots ?? 0;
    final b = _discoveredSlots ?? 0;
    return '$a / $b';
  }

  int _secondsSinceCheck() {
    if (_lastChecked == null) return 0;
    final diff = DateTime.now().difference(_lastChecked!);
    return diff.inSeconds;
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _secondsTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatusItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SlotItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  const _SlotItem({required this.icon, required this.title, required this.subtitle, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class SwapPlaceholder extends StatelessWidget {
  const SwapPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              leading: const BackButton(),
              elevation: 0,
              backgroundColor: Colors.transparent,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.currency_exchange, size: 48),
              const SizedBox(height: 12),
              Text(l10n.swap, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(l10n.tokenSwap, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPlaceholder extends StatelessWidget {
  const StatusPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              leading: const BackButton(),
              elevation: 0,
              backgroundColor: Colors.transparent,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hub, size: 48),
              const SizedBox(height: 12),
              Text(l10n.node, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(l10n.nodeStatus, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class RewardsPlaceholder extends StatelessWidget {
  const RewardsPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              leading: const BackButton(),
              elevation: 0,
              backgroundColor: Colors.transparent,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.card_giftcard, size: 48),
              const SizedBox(height: 12),
              Text(l10n.rewards, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(l10n.rewardsAchievements, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
