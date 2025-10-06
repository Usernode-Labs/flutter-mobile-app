// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/design/design_tokens.dart';
import 'package:crypto_mobile_app/core/widgets/app_action_button.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/wallet_service.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'send_screen.dart';
import 'receive_screen.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as rust_types;
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late WalletService _walletService;
  AccountMeta? _account;

  // UTXO state
  bool _utxosLoading = false;
  String? _utxosError;
  List<OwnedUtxo> _utxos = const [];

  @override
  void initState() {
    super.initState();
    _walletService = WalletService.instance;
    _loadActiveAccount();
  }

  Future<void> _loadActiveAccount() async {
    final repo = await AccountsRepository.create();
    final active = await repo.getActive();
    if (!mounted) return;
    setState(() {
      _account = active;
    });

    if (_account != null && !RustBackendService.instance.isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).backendStarting)),
      );
      await RustBackendService.instance.startForActiveAccount();
    }

    // Fetch UTXOs regardless of active account (forced owner)
    await _fetchUtxos();
  }

  Future<void> _refreshWallet() async {
    try {
      await _walletService.refreshWalletData();
      await _fetchUtxos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to refresh wallet data')),
      );
    }
  }

  Future<void> _fetchUtxos() async {
    setState(() {
      _utxosLoading = true;
      _utxosError = null;
    });
    try {
      // TEMP: Use hard-coded owner address as requested
      const hardcodedOwner = 'AiitAFAG8P8g6uXXu6zmbzsaa5bFXDNwCMYDkSUyH2wU8XLpNG';
      final owner = rust_types.treeHashFromString(s: hardcodedOwner);
      Log.i('UTXO', 'GET rpc.listUtxosByOwner endpoint=node.rpc.listUtxosByOwner params={owner: $hardcodedOwner, limit: null}');
      final resp = await RustBackendService.instance.listUtxosByOwner(owner: owner);
      if (resp == null) {
        Log.w('UTXO', 'rpc.listUtxosByOwner response=null');
      } else {
        final items = resp.items;
        final sample = items.take(3).map((o) => _shortHex(_bytesToHex(o.commitment.field0))).toList();
        Log.i('UTXO', 'rpc.listUtxosByOwner response items=${items.length} sampleCommitments=$sample');
      }
      if (!mounted) return;
      setState(() {
        _utxos = resp?.items ?? const [];
        _utxosLoading = false;
      });
    } catch (e) {
      Log.e('UTXO', 'rpc.listUtxosByOwner failed', e, StackTrace.current);
      if (!mounted) return;
      setState(() {
        _utxosLoading = false;
        _utxosError = 'Failed to load UTXOs';
      });
    }
  }

  // Hex helpers
  String _bytesToHex(Iterable<int> bytes, {bool withPrefix = true}) {
    final sb = StringBuffer(withPrefix ? '0x' : '');
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  String _shortHex(String hex, {int head = 8, int tail = 6}) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (h.length <= head + tail) return '0x$h';
    return '0x${h.substring(0, head)}…${h.substring(h.length - tail)}';
  }

  void _handleSendTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SendScreen()),
    );
  }

  void _handleReceiveTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReceiveScreen()),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _accountColor(ThemeData theme, String addr) {
    final palette = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
    ];
    final idx = addr.hashCode.abs() % palette.length;
    return palette[idx];
  }

  String _shortAddr(String addr) {
    if (addr.length <= 12) return addr;
    final start = addr.substring(0, 6);
    final end = addr.substring(addr.length - 4);
    return '$start…$end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Wallet',
        showWalletAndProfile: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshWallet,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(kSpace16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account Header
                if (_account != null) _buildAccountHeader(theme),
                if (_account != null) const SizedBox(height: kSpace24),

                // Quick Actions
                _buildQuickActions(theme),
                const SizedBox(height: kSpace32),

                // Balances Section
                _buildBalancesSection(theme),
                const SizedBox(height: kSpace24),

                // Activity Section
                _buildActivitySection(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountHeader(ThemeData theme) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _accountColor(theme, _account!.address)
              .withValues(alpha: kAlphaMedium),
          foregroundColor: _accountColor(theme, _account!.address),
          child: const Icon(Icons.account_circle, size: kIconSmall),
        ),
        const SizedBox(width: kSpace12),
        Expanded(
          child: Text(
            _shortAddr(_account!.address),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (FeatureFlags.on('wallet.send'))
          Expanded(
            child: AppActionButton(
              icon: Icons.arrow_upward,
              label: 'Send',
              color: theme.colorScheme.primary,
              onTap: _handleSendTap,
            ),
          ),
        if (FeatureFlags.on('wallet.receive'))
          Expanded(
            child: AppActionButton(
              icon: Icons.arrow_downward,
              label: 'Receive',
              color: theme.colorScheme.tertiary,
              onTap: _handleReceiveTap,
            ),
          ),
        Expanded(
          child: AppActionButton(
            icon: Icons.swap_horiz,
            label: 'Swap',
            color: theme.colorScheme.secondary,
            onTap: () => _showComingSoon('Swap'),
          ),
        ),
        if (FeatureFlags.on('wallet.bridge'))
          Expanded(
            child: AppActionButton(
              icon: Icons.account_balance,
              label: 'Bridge',
              color: theme.colorScheme.primary,
              onTap: () => _showComingSoon('Bridge'),
            ),
          ),
      ],
    );
  }

  Widget _buildBalancesSection(ThemeData theme) {
    // Mock data
    final holdings = [
      {'name': 'Token1', 'symbol': 'TKN', 'amount': 1221},
      {'name': 'Token2', 'symbol': 'TKN', 'amount': 2002},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Balances',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: kSpace12),
        AppCard.regular(
          child: Column(
            children: [
              for (int i = 0; i < holdings.length; i++) ...[
                if (i > 0) const SizedBox(height: kSpace12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: kAlphaStrong),
                      child: Icon(
                        Icons.monetization_on_outlined,
                        color: theme.colorScheme.onSurface,
                        size: kIconSmall,
                      ),
                    ),
                    const SizedBox(width: kSpace16),
                    Expanded(
                      child: Text(
                        holdings[i]['name'] as String,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      '${holdings[i]['amount']} ${holdings[i]['symbol']}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: kSpace12),
        if (_utxosLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: kSpace16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          )
        else if (_utxosError != null)
          AppCard.regular(
            child: Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: kSpace12),
                Expanded(
                  child: Text(
                    _utxosError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_utxos.isEmpty)
          AppCard.regular(
            child: Row(
              children: [
                Icon(Icons.inbox_outlined, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: kSpace12),
                Expanded(
                  child: Text(
                    'No UTXOs found',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (int i = 0; i < _utxos.length; i++) ...[
            if (i > 0) const SizedBox(height: kSpace8),
            AppCard.regular(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.data_object,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: kIconSmall,
                    ),
                  ),
                  const SizedBox(width: kSpace16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show commitment short hex
                        Builder(
                          builder: (_) {
                            final commitment = _utxos[i].commitment;
                            final fullHex = _bytesToHex(commitment.field0);
                            final short = _shortHex(fullHex);
                            return Text(
                              'Commitment: $short',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: kSpace4),
                        Text(
                          'Owned UTXO',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Placeholder for amount when exposed in bindings
                  Text(
                    '',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
