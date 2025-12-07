import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/core/widgets/produced_block_card.dart';
import 'package:crypto_mobile_app/core/widgets/app_progress_bar.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'node_peers_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/node_provider.dart';
import 'package:crypto_mobile_app/features/node/epoch_rewards_provider.dart';
import 'package:crypto_mobile_app/features/node/node_data_providers.dart';
import 'package:crypto_mobile_app/features/wallet/assets_provider.dart';
import 'package:crypto_mobile_app/features/wallet/utxo_provider.dart';
import 'package:crypto_mobile_app/features/wallet/accounts_provider.dart';
import 'package:crypto_mobile_app/features/wallet/models/account.dart';

final _log = LoggingService.instance.withTag(LogTag.node);

class NodeStatusScreen extends ConsumerStatefulWidget {
  const NodeStatusScreen({super.key});

  @override
  ConsumerState<NodeStatusScreen> createState() => _NodeStatusScreenState();
}

class _NodeStatusScreenState extends ConsumerState<NodeStatusScreen>
    with SingleTickerProviderStateMixin {
  bool _refreshing = false;
  String? _error;
  // int? _peerCount; // unused
  List<RpcPeerInfo> _peers = const [];
  int? _currentBlockHeight;
  int? _networkBestTipHeight;
  int? _bestTipGlobalSlot;
  int? _bestTipEpoch;

  // Cached rewards data
  int? _producedInEpoch;
  int? _winsInEpoch;
  BigInt? _rewardPerBlock;

  // Cached wallet balance
  BigInt? _cachedBalance;
  String? _cachedTokenSymbol;

  Timer? _autoTimer;
  late final TabController _tabController;
  DateTime? _lastChecked;
  bool _active = false; // active when NodeStatus tab is selected (index 1)

  // Collapsible section states
  bool _isRecentBlocksExpanded = false;

  // Wallet balance state
  AccountMeta? _account;

  // Device ID
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Defer provider modifications until after first frame to avoid
    // "modify provider while building" errors when navigating.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _loadActiveAccount();
      _loadDeviceId();
    });
    // Start timer immediately since we're on this screen
    // The build() method will handle stopping it if tab changes
    _active = true;
    _startTimer();
  }

  Future<void> _loadActiveAccount() async {
    final repo = await AccountsRepository.create();
    final active = await repo.getActive();
    if (!mounted) return;
    setState(() {
      _account = active;
    });
    // Prime UTXO provider to trigger asset loading
    ref.read(walletUtxosProvider.future);
  }

  Future<void> _loadDeviceId() async {
    // Only load once - device ID doesn't change
    if (_deviceId != null) return;

    final deviceInfo = DeviceInfoPlugin();
    String rawDeviceId = 'unknown';
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      rawDeviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      rawDeviceId = iosInfo.identifierForVendor ?? 'unknown';
    }
    // Hash the device ID (same as metrics collector)
    final bytes = utf8.encode(rawDeviceId);
    final digest = sha256.convert(bytes);
    final hashedDeviceId = digest.toString().substring(0, 16);

    if (!mounted) return;
    setState(() {
      _deviceId = hashedDeviceId;
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _error = null; // keep content visible; show error inline
    });
    try {
      // Refresh all providers (using notifier.refresh() to avoid loading state flicker)
      await ref.read(nodeStatusProvider.notifier).refresh();
      await ref.read(nodeMempoolProvider.notifier).refresh();
      await ref.read(nodeBlockchainProvider.notifier).refresh();
      await ref.read(epochRewardsProvider.notifier).refresh();
      // Refresh wallet UTXOs to update balance after node syncs (silent to avoid flicker)
      await ref.read(walletUtxosProvider.notifier).silentRefresh();

      // Check if still mounted after async operations
      if (!mounted) return;

      // Get the status for UI state
      final status = ref.read(nodeStatusProvider).value;
      if (status != null) {
        final localBestTip = status.localBest;
        final networkBestTip = status.networkBest;
        final displayBestTip = networkBestTip ?? localBestTip;

        if (!mounted) return;
        setState(() {
          _peers = status.peers;
          _currentBlockHeight = localBestTip?.height;
          _networkBestTipHeight = networkBestTip?.height;
          _bestTipGlobalSlot = displayBestTip?.globalSlot;
          _bestTipEpoch = displayBestTip?.epoch;
          _lastChecked = DateTime.now();

          // Cache rewards data
          final rewardsData = ref.read(epochRewardsProvider).value;
          if (rewardsData != null) {
            _producedInEpoch = rewardsData.producedInEpoch;
            _winsInEpoch = rewardsData.winsInEpoch;
            _rewardPerBlock = rewardsData.rewardPerBlock;
          }

          // Cache wallet balance
          final assetsData = ref.read(walletAssetsProvider).value;
          if (assetsData != null && assetsData.isNotEmpty) {
            _cachedBalance = assetsData.fold<BigInt>(
                BigInt.zero, (sum, a) => sum + a.totalBalance);
            _cachedTokenSymbol = assetsData.first.tokenSymbol;
          }
        });
      }
    } on StateError catch (e, st) {
      // Happens if a late timer tick fires after disposal; just log quietly.
      _log.debug('Skipped refresh on disposed node screen');
      _log.debug('StateError during refresh: $e');
      _log.debug('Stack trace: $st');
      return;
    } catch (e, st) {
      _log.error('Refresh failed', error: e, stackTrace: st);
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
    // React to tab changes and start/stop timers
    final currentTab = ref.watch(currentHomeTabProvider);
    final shouldBeActive = currentTab == 1;
    if (shouldBeActive != _active) {
      _active = shouldBeActive;
      if (_active) {
        _startTimer();
      } else {
        _stopTimer();
      }
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.commonError,
                        style: TextStyle(color: colorScheme.error)),
                    const SizedBox(height: 6),
                    Text(_error!, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 16),
                  ],
                ),

              // WALLET BALANCE Section (moved to bottom)
              _buildWalletBalanceCard(theme),
              const SizedBox(height: 8),

              // OVERVIEW Section (includes Synchronization details)
              _buildOverviewSection(
                  context, ref.read(nodeStatusProvider).value),
              const SizedBox(height: 8),

              // RECENT BLOCKS Section (collapsible, separate card)
              _buildRecentBlocksSection(context),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build diary-style card wrapper
  Widget _buildDiaryCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceBright,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  // Wallet balance card widget
  Widget _buildWalletBalanceCard(ThemeData theme) {
    final peerId = ref.read(nodeStatusProvider).value?.peerId;
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance amount
            Text(
              'Balance: ${_formatBalance((_cachedBalance ?? BigInt.zero).toDouble())} ${_cachedTokenSymbol ?? 'TKN'}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Address row
            Text(
              'address:   ${_account != null ? _shortAddr(_account!.address) : 'NA'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
            if (peerId != null) ...[
              const SizedBox(height: 2),
              Text(
                'peerId:   ${_shortenMid(peerId, head: 6, tail: 6)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            if (_deviceId != null) ...[
              const SizedBox(height: 2),
              Text(
                'deviceId: $_deviceId',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper for shortened address display
  String _shortAddr(String addr) {
    if (addr.length <= 12) return addr;
    final start = addr.substring(0, 10);
    final end = addr.substring(addr.length - 10);
    return '$start…$end';
  }

  // Helper for formatting balance
  String _formatBalance(double amount) {
    final formatter = NumberFormat('#,##0.##', 'en_US');
    return formatter.format(amount);
  }

  // Helper method for section headers (unused - integrated into cards)
  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.bodyLarge!.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildOverviewSection(
      BuildContext context, NodeStatusState? statusFromProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sync = statusFromProvider?.syncStatus;
    final isSynced = sync?.isSynced ?? false;

    // Calculate sync percentage - now based on applied blocks progress from sync status
    final syncPercentage = sync?.progress ?? 0.0;

    // Determine what to display for block counts
    String blockDisplayText;
    final currentHeight =
        statusFromProvider?.localBestHeight ?? _currentBlockHeight ?? 0;
    final networkHeight = statusFromProvider?.networkBestHeight ??
        _networkBestTipHeight ??
        currentHeight;
    if (sync == null || sync.isConnecting) {
      // Don't show block count when connecting
      blockDisplayText = '';
    } else if (isSynced) {
      // When synced, show block height
      blockDisplayText = 'Block $currentHeight / $networkHeight';
    } else if (sync.appliedBlocks != null && sync.targetBlocks != null) {
      // Use applied blocks data when syncing
      final appliedStr = _formatBigIntStatic(sync.appliedBlocks!);
      final targetStr = _formatBigIntStatic(sync.targetBlocks!);
      blockDisplayText = 'Block $appliedStr / $targetStr';
    } else {
      // Fallback to height-based display
      blockDisplayText = 'Block $currentHeight / $networkHeight';
    }

    // Derive the current slot within the epoch from global slot, epoch, and slots per epoch.
    int? epochSlot;
    final curGlobalSlot = statusFromProvider?.currentGlobalSlot;
    final curEpoch = statusFromProvider?.currentEpoch;
    final slotsInEpoch = statusFromProvider?.slotsInEpoch;
    if (curGlobalSlot != null &&
        curEpoch != null &&
        slotsInEpoch != null &&
        slotsInEpoch > 0) {
      epochSlot = curGlobalSlot - curEpoch * slotsInEpoch;
    }

    // Peer status
    int connectedPeers;
    int totalPeers;
    if (statusFromProvider != null) {
      connectedPeers = statusFromProvider.connectedPeers;
      totalPeers = statusFromProvider.totalPeers;
    } else {
      final status = ref.read(nodeStatusProvider).value;
      if (status != null) {
        connectedPeers = status.connectedPeers;
        totalPeers = status.totalPeers;
      } else {
        connectedPeers = 0;
        totalPeers = 0;
      }
    }
    final peerHealthy = connectedPeers > 0 && connectedPeers == totalPeers;

    // Determine status display based on connection state
    final IconData statusIcon;
    final String statusLabel;
    final Color accentColor;

    if (sync == null || sync.isConnecting) {
      statusIcon = Icons.hourglass_empty;
      statusLabel = 'Connecting';
      accentColor = colorScheme.outline;
    } else if (isSynced) {
      statusIcon = Icons.check_circle;
      statusLabel = 'Synced';
      accentColor = colorScheme.tertiary;
    } else {
      statusIcon = Icons.sync;
      statusLabel = 'Syncing';
      accentColor = colorScheme.primary;
    }

    return _buildDiaryCard(
      context: context,
      children: [
        _buildSectionHeader(context, 'Overview'),
        const SizedBox(height: 12),

        // Status line
        Row(
          children: [
            Icon(
              statusIcon,
              size: 18,
              color: accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              statusLabel,
              style: theme.textTheme.titleMedium!
                  .copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.18)
                  .copyWith(
                    color: accentColor,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '•',
              style: theme.textTheme.bodyMedium!
                  .copyWith(fontSize: 14, letterSpacing: 0.2)
                  .copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                blockDisplayText,
                style: theme.textTheme.bodyMedium!
                    .copyWith(fontSize: 14, letterSpacing: 0.2),
              ),
            ),
            Text(
              '${(syncPercentage * 100).toStringAsFixed(1)}%',
              style: theme.textTheme.titleMedium!
                  .copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.18)
                  .copyWith(
                    color: accentColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Progress bar
        AppProgressBar(
          value: syncPercentage,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: accentColor,
        ),

        const SizedBox(height: 12),

        // Sync Details subsection
        _buildSyncDetailsSubsection(context),

        const SizedBox(height: 12),

        // Peers and Epoch info row
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildCompactInfoCard(
                  context,
                  label: 'Peers',
                  value: '$connectedPeers/$totalPeers',
                  subtitle: peerHealthy ? 'All connected' : 'Some offline',
                  color: peerHealthy
                      ? colorScheme.tertiary
                      : colorScheme.error.withValues(alpha: 0.7),
                  colorScheme: colorScheme,
                  onTap: () {
                    final status = ref.read(nodeStatusProvider).value;
                    final peers = (status?.peers.isNotEmpty == true)
                        ? status!.peers
                        : _peers;
                    if (peers.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NodePeersScreen(peers: peers),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactInfoCard(
                  context,
                  label: 'Cur. Epoch',
                  value: '${statusFromProvider?.currentEpoch ?? 'N/A'}',
                  subtitle: 'Cur. Slot $curGlobalSlot',
                  color: colorScheme.primary,
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // VRF/Slots/Blocks card (full width)
        Builder(
          builder: (context) {
            final produced =
                ref.read(epochRewardsProvider).value?.producedInEpoch ??
                    _producedInEpoch ??
                    0;
            var wonSlots =
                ref.read(epochRewardsProvider).value?.wonSlots.length ??
                    ref.read(epochRewardsProvider).value?.winsInEpoch ??
                    _winsInEpoch ??
                    0;
            if (wonSlots < produced) {
              wonSlots = produced;
            }

            final vrfEvaluator =
                ref.read(nodeStatusProvider).value?.vrfEvaluator;
            final evaluatedSlots =
                vrfEvaluator?.details?.evaluatedCurrentEpoch ?? 0;
            final totalSlotsPerEpoch =
                ref.read(nodeStatusProvider).value?.slotsInEpoch ?? 0;

            final vrfStatus = vrfEvaluator?.currentEpochVrfEvaluationStatus;
            final statusText = switch (vrfStatus) {
              RpcStatusVrfEvaluationStatus.pending => 'Pending',
              RpcStatusVrfEvaluationStatus.evaluating => 'Evaluating',
              RpcStatusVrfEvaluationStatus.completed => 'Completed',
              _ => 'N/A',
            };

            return _buildMultiLineInfoCard(
              context,
              label:
                  'VRF (Epoch Slots: ${NumberFormat('#,###').format(totalSlotsPerEpoch)} / Status: $statusText)',
              lines: [
                'Evaluated Slots: ${NumberFormat('#,###').format(evaluatedSlots)}',
                'Won Slots: ${NumberFormat('#,###').format(wonSlots)}',
                'Produced Blocks: ${NumberFormat('#,###').format(produced)}',
              ],
              color: colorScheme.tertiary,
              colorScheme: colorScheme,
              onTap: () => context.push(AppRoutes.mainNodeWonSlots),
              useGradient: false,
            );
          },
        ),

        const SizedBox(height: 12),

        // Best Tip and Mempool row
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildMultiLineInfoCard(
                  context,
                  label: 'Best Tip',
                  lines: () {
                    final status = ref.read(nodeStatusProvider).value;
                    final localBestTip = status?.localBest;
                    final networkBestTip = status?.networkBest;
                    final displayBestTip = networkBestTip ?? localBestTip;

                    if (displayBestTip == null) return ['N/A'];

                    final height = displayBestTip.height;
                    final hash = displayBestTip.hash.toString();
                    final epoch = status?.epoch ?? _bestTipEpoch;
                    final slot = status?.globalSlot ?? _bestTipGlobalSlot;

                    final formattedHeight =
                        'Height ${NumberFormat('#,###').format(height)}';
                    final epochText = 'Epoch ${epoch ?? 'N/A'}';
                    final slotText = 'Slot ${slot ?? 'N/A'}';
                    final truncatedHash = hash.length > 16
                        ? '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}'
                        : hash;

                    return [
                      formattedHeight,
                      epochText,
                      slotText,
                      truncatedHash
                    ];
                  }(),
                  color: colorScheme.tertiary,
                  colorScheme: colorScheme,
                  useGradient: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMultiLineInfoCard(
                  context,
                  label: 'Mempool',
                  lines: () {
                    final mempool = ref.read(nodeMempoolProvider).value;
                    if (mempool == null) return ['N/A'];

                    final count = mempool.count.toInt();
                    final orphans = mempool.orphans.toInt();
                    final sizeKB =
                        (mempool.totalSize.toInt() / 1024).toStringAsFixed(1);

                    return [
                      count == 1 ? '1 txn' : '$count txns',
                      '$sizeKB KB',
                      orphans == 1 ? '1 orphan' : '$orphans orphans',
                    ];
                  }(),
                  color: colorScheme.secondary,
                  colorScheme: colorScheme,
                  onTap: () => context.push(AppRoutes.mainNodeMempool),
                  useGradient: false,
                ),
              ),
            ],
          ),
        ),

        if (_lastChecked != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatLastChecked(),
              style: theme.textTheme.bodySmall!
                  .copyWith(
                      fontSize: 12,
                      letterSpacing: 0.2,
                      color: colorScheme.onSurfaceVariant)
                  .copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactInfoCard(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
    bool useGradient = false,
  }) {
    final theme = Theme.of(context);

    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
          color: useGradient ? null : Colors.transparent,
          gradient: useGradient
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    // Glassmorphism: white overlay blended with color
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.04),
                      color.withValues(alpha: 0.08),
                    ),
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.02),
                      color.withValues(alpha: 0.04),
                    ),
                  ],
                )
              : null,
          border: useGradient
              ? Border.all(
                  color:
                      color.withValues(alpha: 0.8), // Semi-transparent border
                  width: 1.0,
                )
              : Border.all(
                  color: colorScheme.outlineVariant,
                  width: 1.0,
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: useGradient
              ? [
                  // Soft glow with color tint
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 8.0,
                    spreadRadius: 2,
                  ),
                  // Subtle depth shadow
                ]
              : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          letterSpacing: 0.2,
                          color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // Show chevron arrow for clickable cards
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 20,
              color: color.withValues(alpha: 0.5),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: card,
      );
    }

    return card;
  }

  Widget _buildMultiLineInfoCard(
    BuildContext context, {
    required String label,
    required List<String> lines,
    required Color color,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
    bool useGradient = false,
  }) {
    final theme = Theme.of(context);

    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
          color: useGradient ? null : Colors.transparent,
          gradient: useGradient
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.04),
                      color.withValues(alpha: 0.08),
                    ),
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.02),
                      color.withValues(alpha: 0.04),
                    ),
                  ],
                )
              : null,
          border: useGradient
              ? Border.all(
                  color: color.withValues(alpha: 0.8),
                  width: 1.0,
                )
              : Border.all(
                  color: colorScheme.outlineVariant,
                  width: 1.0,
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: useGradient
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 8.0,
                    spreadRadius: 2,
                  ),
                ]
              : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall!.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      letterSpacing: 0.2,
                      color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                ...lines.map((line) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        line,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
              ],
            ),
          ),
          // Show chevron arrow for clickable cards
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 20,
              color: color.withValues(alpha: 0.5),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: card,
      );
    }

    return card;
  }

  // Sync Details subsection - shown within Overview card
  Widget _buildSyncDetailsSubsection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = ref.read(nodeStatusProvider).value;
    final fetchProgress = status?.fetchProgress;
    final applyProgress = status?.applyProgress;

    // Calculate percentages
    double fetchPercentage = 0.0;
    double applyPercentage = 0.0;

    if (fetchProgress != null) {
      final total =
          fetchProgress.idle + fetchProgress.pending + fetchProgress.done;
      if (total > BigInt.zero) {
        fetchPercentage =
            (fetchProgress.done.toDouble() / total.toDouble()) * 100;
      } else {
        fetchPercentage = 100.0;
      }
    } else {
      fetchPercentage = 100.0;
    }

    if (applyProgress != null) {
      final total =
          applyProgress.idle + applyProgress.pending + applyProgress.done;
      if (total > BigInt.zero) {
        applyPercentage =
            (applyProgress.done.toDouble() / total.toDouble()) * 100;
      } else {
        applyPercentage = 100.0;
      }
    } else {
      applyPercentage = 100.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subsection header
        Text(
          'Sync Details',
          style: theme.textTheme.bodySmall!
              .copyWith(
                  fontSize: 12,
                  letterSpacing: 0.2,
                  color: colorScheme.onSurfaceVariant)
              .copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
        ),
        const SizedBox(height: 12),

        // Horizontal row of circular progress cards
        Row(
          children: [
            // Fetch progress card
            Expanded(
              child: _buildLinearProgressCard(
                context: context,
                label: 'Fetch Blocks',
                percentage: fetchPercentage,
                color: fetchPercentage >= 100.0
                    ? colorScheme.tertiary
                    : (colorScheme.brightness == Brightness.light
                        ? colorScheme.primary
                        : colorScheme.primaryFixed),
                done: fetchProgress?.done,
                pending: fetchProgress?.pending,
                idle: fetchProgress?.idle,
              ),
            ),
            const SizedBox(width: 12),
            // Apply progress card
            Expanded(
              child: _buildLinearProgressCard(
                context: context,
                label: 'Apply Blocks',
                percentage: applyPercentage,
                color: applyPercentage >= 100.0
                    ? colorScheme.tertiary
                    : colorScheme.secondary,
                done: applyProgress?.done,
                pending: applyProgress?.pending,
                idle: applyProgress?.idle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper method to build linear progress card with row layout
  Widget _buildLinearProgressCard({
    required BuildContext context,
    required String label,
    required double percentage,
    required Color color,
    BigInt? done,
    BigInt? pending,
    BigInt? idle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 1.0,
          )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium!.copyWith(
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium!.copyWith(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppProgressBar(
            value: percentage / 100.0,
            valueColor: color,
            height: 12,
          ),
          const SizedBox(height: 8),
          // Stats (if available)
          if (done != null && pending != null && idle != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Done: $done',
                  style: theme.textTheme.bodySmall!
                      .copyWith(
                          fontSize: 12,
                          letterSpacing: 0.2,
                          color: colorScheme.onSurfaceVariant)
                      .copyWith(
                        fontSize: 10,
                      ),
                ),
                Text(
                  'Pending: $pending',
                  style: theme.textTheme.bodySmall!
                      .copyWith(
                          fontSize: 12,
                          letterSpacing: 0.2,
                          color: colorScheme.onSurfaceVariant)
                      .copyWith(
                        fontSize: 10,
                      ),
                ),
                Text(
                  'Idle: $idle',
                  style: theme.textTheme.bodySmall!
                      .copyWith(
                          fontSize: 12,
                          letterSpacing: 0.2,
                          color: colorScheme.onSurfaceVariant)
                      .copyWith(
                        fontSize: 10,
                      ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // NEW method: Separate Recent Blocks section
  Widget _buildRecentBlocksSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blockchain = ref.read(nodeBlockchainProvider).value;

    // Don't show section if no blocks available
    if (blockchain == null || blockchain.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildDiaryCard(
      context: context,
      children: [
        // Header row with expand/collapse icon
        InkWell(
          onTap: () {
            setState(() {
              _isRecentBlocksExpanded = !_isRecentBlocksExpanded;
            });
          },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Blocks',
                  style: theme.textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!_isRecentBlocksExpanded)
                TextButton(
                  onPressed: () =>
                      context.push(AppRoutes.nodeStatusProducedBlocks),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: theme.textTheme.bodySmall!
                            .copyWith(
                                fontSize: 12,
                                letterSpacing: 0.2,
                                color: colorScheme.onSurfaceVariant)
                            .copyWith(
                              color: colorScheme.primary,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward,
                          size: 14, color: colorScheme.primary),
                    ],
                  ),
                ),
              Icon(
                _isRecentBlocksExpanded ? Icons.expand_less : Icons.expand_more,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),

        // Collapsible content
        if (_isRecentBlocksExpanded) ...[
          const SizedBox(height: 12),
          _buildProducedBlocksTab(context),
        ],
      ],
    );
  }

  // ignore: unused_element
  Color _statusColor(ThemeData theme, PeerConnectionStatus s) {
    final colorScheme = theme.colorScheme;
    switch (s) {
      case PeerConnectionStatus.connected:
        return colorScheme.tertiary;
      case PeerConnectionStatus.connecting:
        return colorScheme.primary;
      case PeerConnectionStatus.disconnected:
        return colorScheme.error;
      case PeerConnectionStatus.disconnecting:
        return colorScheme.error.withValues(alpha: 0.7);
    }
  }

  // ignore: unused_element
  String? _peerIp(RpcPeerInfo p) {
    // Prefer address field, then connectingDetails
    final addr = _extractIpPort(p.address);
    if (addr != null) return addr;
    final det = _extractIpPort(p.connectingDetails);
    return det;
  }

  // ignore: unused_element
  String? _peerIpOnly(RpcPeerInfo p) {
    // Prefer address field, then connectingDetails
    final addr = _extractIpOnly(p.address);
    if (addr != null) return addr;
    final det = _extractIpOnly(p.connectingDetails);
    return det;
  }

  String? _extractIpPort(String? text) {
    if (text == null) return null;
    final s = text.trim();
    // Multiaddr form: /ip4/<ip>/tcp/<port>/p2p/<peerId> (or ip6/dns)
    if (s.startsWith('/')) {
      final parts = s.split('/').where((e) => e.isNotEmpty).toList();
      String? host;
      String? port;
      for (var i = 0; i < parts.length - 1; i++) {
        final t = parts[i].toLowerCase();
        if (t == 'ip4' || t == 'ip6' || t.startsWith('dns')) {
          host = parts[i + 1];
        }
        if (t == 'tcp' || t == 'udp') {
          port = i + 1 < parts.length ? parts[i + 1] : null;
        }
      }
      if (host != null && port != null) return '$host:$port';
      if (host != null) return host;
    }
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

  String? _extractIpOnly(String? text) {
    if (text == null) return null;
    final s = text.trim();
    // Multiaddr form: /ip4/<ip>/tcp/<port>/p2p/<peerId> (or ip6/dns)
    if (s.startsWith('/')) {
      final parts = s.split('/').where((e) => e.isNotEmpty).toList();
      for (var i = 0; i < parts.length - 1; i++) {
        final t = parts[i].toLowerCase();
        if (t == 'ip4' || t == 'ip6' || t.startsWith('dns')) {
          return parts[i + 1];
        }
      }
    }
    // IPv6 in brackets or raw
    final ipv6Br = RegExp(r'\[([0-9a-fA-F:]+)\]').firstMatch(s);
    if (ipv6Br != null) return ipv6Br.group(0);
    final ipv6Raw = RegExp(r'\b[0-9a-fA-F:]{2,}\b').firstMatch(s);
    if (ipv6Raw != null && ipv6Raw.group(0)!.contains(':')) {
      return ipv6Raw.group(0);
    }
    // IPv4 only
    final ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})').firstMatch(s);
    if (ipv4 != null) return ipv4.group(1);
    // Hostname only
    final hostOnly = RegExp(r'^([A-Za-z0-9.-]+)').firstMatch(s)?.group(1);
    return hostOnly;
  }

  String _formatUtc(BigInt value) {
    // Heuristic to interpret epoch unit from digit length
    final digits = value.toString().length;
    BigInt ms;
    if (digits >= 19) {
      // nanoseconds -> ms
      ms = value ~/ BigInt.from(1000000);
    } else if (digits >= 16) {
      // microseconds -> ms
      ms = value ~/ BigInt.from(1000);
    } else if (digits >= 13) {
      // already milliseconds
      ms = value;
    } else {
      // seconds -> ms
      ms = value * BigInt.from(1000);
    }
    final millis = ms.toInt();
    final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    // ISO 8601 UTC
    return dt.toIso8601String();
  }

  // ignore: unused_element
  String _formatTimeAgo(BigInt value) {
    // Convert using the same unit heuristic as _formatUtc
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

  String _formatLastChecked() {
    if (_lastChecked == null) return '';

    final now = DateTime.now();
    final checked = _lastChecked!;

    // Format time as HH:MM:SS
    final hour = checked.hour.toString().padLeft(2, '0');
    final minute = checked.minute.toString().padLeft(2, '0');
    final second = checked.second.toString().padLeft(2, '0');

    // Check if it's today
    final isToday = now.year == checked.year &&
        now.month == checked.month &&
        now.day == checked.day;

    if (isToday) {
      return 'Last checked at $hour:$minute:$second';
    } else {
      // Show date if not today
      final month = checked.month.toString().padLeft(2, '0');
      final day = checked.day.toString().padLeft(2, '0');
      return 'Last checked on ${checked.year}-$month-$day at $hour:$minute:$second';
    }
  }

  static String _formatBigIntStatic(BigInt value) {
    final formatter = NumberFormat('#,###', 'en_US');
    // Convert BigInt to int for formatting (safe for reasonable block counts)
    try {
      return formatter.format(value.toInt());
    } catch (e) {
      // Fallback for very large numbers that don't fit in int
      return value.toString();
    }
  }

  Widget _buildProducedBlocksTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blockchain = ref.read(nodeBlockchainProvider).value;
    final status = ref.read(nodeStatusProvider).value;
    final rewards = ref.read(epochRewardsProvider).value;

    if (blockchain == null || blockchain.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No produced blocks available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Display blocks from the blockchain
    final blocks = blockchain.items.take(10).toList();
    final bestTipSlot = status?.globalSlot ?? _bestTipGlobalSlot;
    final rewardPerBlock =
        rewards?.rewardPerBlock ?? _rewardPerBlock ?? BigInt.zero;

    return Column(
      children: blocks.asMap().entries.map((entry) {
        final block = entry.value;
        final isBestTip =
            bestTipSlot != null && block.globalSlot == bestTipSlot;

        String blockHash;
        try {
          blockHash = block.hash.toString();
        } catch (e) {
          blockHash = 'N/A';
        }

        String producerPubkey;
        try {
          producerPubkey = block.producerPubkey;
        } catch (e) {
          producerPubkey = '';
        }

        return ProducedBlockCard(
          block: block,
          isBestTip: isBestTip,
          customHash: blockHash,
          customProducer: producerPubkey,
          rewardPerBlock: rewardPerBlock,
          variant: BlockCardVariant.detailed,
        );
      }).toList(),
    );
  }

  // Helper method to shorten long strings (e.g., peer IDs) for display
  String _shortenMid(String s, {int head = 8, int tail = 8}) {
    if (s.length <= head + tail + 1) return s;
    return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _active && !_refreshing) {
        _refresh();
      }
    });
  }

  void _stopTimer() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }
}
