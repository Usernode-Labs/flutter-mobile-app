import 'dart:async';
import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/services/rust_backend_service.dart';
import 'package:crypto_mobile_app/utils/logger.dart';

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
    setState(() {
      _refreshing = true;
      _error = null; // keep content visible; show error inline
    });
    try {
      Log.d('NODE', 'Fetching status');
      final status = await RustBackendService.instance.getStatus();
      setState(() {
        _peerCount = status?.peers.length;
        // TODO: Map real fields once exposed by RPC (placeholders for now)
        _blockHeight = null;
        _mempoolCount = null;
        _evaluatedSlots = null;
        _discoveredSlots = null;
        _lastChecked = DateTime.now();
      });
    } catch (e, st) {
      Log.e('NODE', 'getStatus failed', e, st);
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                      _StatusItem(label: l10n.currentBlockHeightLabel, value: _fmtInt(_blockHeight)),
                      const SizedBox(height: 16),
                      _StatusItem(label: l10n.nodeStatusLabel, value: _statusText(l10n)),
                      const SizedBox(height: 16),
                      _StatusItem(label: l10n.peersLabel, value: (_peerCount ?? 0).toString()),
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
