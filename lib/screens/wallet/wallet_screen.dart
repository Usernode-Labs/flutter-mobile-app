import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../models/transaction_model.dart';
import '../../services/wallet_service.dart';
import '../../widgets/wallet/wallet_widgets.dart';
import 'send_screen.dart';
import 'receive_screen.dart';
import 'package:crypto_mobile_app/config/feature_flags.dart';
import 'package:crypto_mobile_app/services/accounts_repository.dart';
import 'package:crypto_mobile_app/models/account.dart';
import '../onboarding/account_onboarding_screen.dart';
import 'package:flutter/services.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto_mobile_app/services/rust_backend_service.dart';
import 'import_account_sheets.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late WalletService _walletService;
  late WalletBalance _balance;
  late List<TransactionModel> _transactions;
  bool _isLoading = false;
  AccountMeta? _account;
  final bool _accountExpanded =
      false; // no longer used for details; used for selector arrow only

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
  void initState() {
    super.initState();
    _walletService = WalletService.instance;
    _loadWalletData();
    _loadActiveAccount();
  }

  void _loadWalletData() {
    setState(() {
      _balance = _walletService.getBalance();
      _transactions = _walletService.getRecentTransactions();
    });
  }

  Future<void> _loadActiveAccount() async {
    final repo = await AccountsRepository.create();
    final active = await repo.getActive();
    if (!mounted) return;
    setState(() {
      _account = active;
    });
    // Ensure backend is started for the active account; show info if starting
    if (_account != null && !RustBackendService.instance.isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).backendStarting)),
      );
      await RustBackendService.instance.startForActiveAccount();
    }
  }

  Future<void> _openAccountManager() async {
    final repo = await AccountsRepository.create();
    final items = await repo.list();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final controller = TextEditingController();
        final keyCtrl = TextEditingController();
        final seedCtrl = TextEditingController();
        String? selectedId = _account?.id;
        return StatefulBuilder(builder: (ctx, setStateSheet) {
          Color accountColor(ThemeData theme, String addr) {
            final palette = [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
              theme.colorScheme.tertiary,
            ];
            final idx = addr.hashCode.abs() % palette.length;
            return palette[idx];
          }

          Future<void> select(String id) async {
            await (await AccountsRepository.create()).setActiveId(id);
            final active =
                await (await AccountsRepository.create()).getActive();
            if (mounted) setState(() => _account = active);
            await RustBackendService.instance.restartForActiveAccount();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text(AppLocalizations.of(context).backendStarting)),
              );
            }
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          }

          Future<void> createNew() async {
            Navigator.of(ctx).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AccountOnboardingScreen()),
            ).then((_) => _loadActiveAccount());
          }

          Future<void> importWithSeed() async {
            final result = await showModalBottomSheet<ImportSeedData>(
              context: ctx,
              isScrollControlled: true,
              useSafeArea: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => ImportSeedSheet(
                initialName: 'Imported ${items.length + 1}',
              ),
            );
            if (result != null) {
              final res = await (await AccountsRepository.create())
                  .importFromMnemonic(
                      name: result.name, mnemonic: result.mnemonic);
              if (res == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to import account')),
                  );
                }
              } else {
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadActiveAccount();
                }
              }
            }
          }

          Future<void> importWithPrivateKey() async {
            final result = await showModalBottomSheet<ImportPrivateKeyData>(
              context: ctx,
              isScrollControlled: true,
              useSafeArea: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => ImportPrivateKeySheet(
                initialName: 'Imported ${items.length + 1}',
              ),
            );
            if (result != null) {
              final res = await (await AccountsRepository.create())
                  .importFromPrivateKey(
                name: result.name,
                privateKey: result.privateKey,
              );
              if (res == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to import account')),
                  );
                }
              } else {
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadActiveAccount();
                }
              }
            }
          }

          final others = items.where((a) => a.id != _account?.id).toList();

          // Enhanced UI/UX for account manager with identicons and animations
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Select account',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  )),
                              const SizedBox(height: 4),
                              Text('Tap an account to switch',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer
                                        .withOpacity(0.8),
                                  )),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: theme.colorScheme.onPrimaryContainer,
                          onPressed: () => Navigator.of(ctx).pop(),
                        )
                      ],
                    ),
                  ),

                  // Accounts list
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (c, i) {
                        final acc = items[i];
                        final isSelected = acc.id == selectedId;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withOpacity(0.06)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setStateSheet(() => selectedId = acc.id);
                              Future.delayed(const Duration(milliseconds: 200),
                                  () {
                                select(acc.id);
                              });
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  // Colorful account icon
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor:
                                          accountColor(theme, acc.address)
                                              .withOpacity(0.12),
                                      foregroundColor:
                                          accountColor(theme, acc.address),
                                      child: const Icon(
                                          Icons.account_circle_outlined),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Texts
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          acc.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _shortAddr(acc.address),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    transitionBuilder: (child, anim) =>
                                        ScaleTransition(
                                      scale: anim,
                                      child: child,
                                    ),
                                    child: isSelected
                                        ? Icon(Icons.check_circle,
                                            key: ValueKey(acc.id),
                                            color: theme.colorScheme.primary)
                                        : const SizedBox.shrink(
                                            key: ValueKey('empty')),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.secondary.withOpacity(0.12),
                            foregroundColor: theme.colorScheme.secondary,
                            child: const Icon(Icons.add),
                          ),
                          title: const Text('Create new account'),
                          onTap: createNew,
                        ),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.tertiary.withOpacity(0.12),
                            foregroundColor: theme.colorScheme.tertiary,
                            child: const Icon(Icons.key),
                          ),
                          title: const Text('Import from seed phrase'),
                          onTap: importWithSeed,
                        ),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.errorContainer
                                .withOpacity(0.25),
                            foregroundColor: theme.colorScheme.error,
                            child: const Icon(Icons.vpn_key),
                          ),
                          title: const Text('Import from private key'),
                          onTap: importWithPrivateKey,
                        ),
                        if (FeatureFlags.on('dev.deleteAccounts')) ...[
                          const Divider(),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.error.withOpacity(0.12),
                              foregroundColor: theme.colorScheme.error,
                              child: const Icon(Icons.delete_forever),
                            ),
                            title: const Text('Delete all accounts (dev)'),
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: ctx,
                                builder: (dctx) => AlertDialog(
                                  title: const Text('Delete all accounts?'),
                                  content: const Text(
                                      'This will remove all stored accounts on this device.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dctx, true),
                                      style: TextButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.error),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await (await AccountsRepository.create())
                                    .deleteAll();
                                if (mounted) {
                                  setState(() => _account = null);
                                  Navigator.of(ctx).pop();
                                  // ignore: use_build_context_synchronously
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AccountOnboardingScreen(),
                                    ),
                                  ).then((_) => _loadActiveAccount());
                                }
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // Removed balance visibility toggle: balances are always visible now.

  Future<void> _refreshWallet() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _walletService.refreshWalletData();
      _loadWalletData();
    } catch (e) {
      _showErrorSnackBar('Failed to refresh wallet data');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  void _handleBridgeTap() {
    _showComingSoon('Bridge');
  }

  void _handleTransactionTap(TransactionModel transaction) {
    // TODO: Navigate to transaction details
    _showComingSoon('Transaction details for ${transaction.title}');
  }

  List<TokenHolding> _topHoldingsFromBalance() {
    // Mock data matching the Gallery design
    return [
      TokenHolding(
        name: 'Token1',
        symbol: 'TKN',
        amount: 1221,
        usdValue: 0,
        icon: Icons.monetization_on_outlined,
      ),
      TokenHolding(
        name: 'Token2',
        symbol: 'TKN',
        amount: 2002,
        usdValue: 0,
        icon: Icons.monetization_on_outlined,
      ),
    ];
  }

  List<Widget> _buildTokenList(ThemeData theme) {
    final holdings = _topHoldingsFromBalance();
    return holdings
        .map((token) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        theme.colorScheme.primaryContainer.withOpacity(0.3),
                    child: Icon(
                      token.icon,
                      color: theme.colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      token.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${token.amount.toInt()} ${token.symbol}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }

  List<Widget> _buildActivityList(ThemeData theme) {
    // Mock activity data matching Gallery design
    final activities = [
      {
        'type': 'send',
        'title': 'Send',
        'date': 'August 19, 2025',
        'amount': '-1.0 Tokens',
        'color': Colors.pink,
        'icon': Icons.north_east,
      },
      {
        'type': 'receive',
        'title': 'Received',
        'date': 'August 19, 2025',
        'amount': '+1.0 Tokens',
        'color': theme.colorScheme.primaryContainer,
        'icon': Icons.south_west,
      },
      {
        'type': 'send',
        'title': 'Send -2.5 Tokens',
        'date': 'August 19, 2025',
        'amount': '-1.0 Tokens',
        'color': Colors.pink,
        'icon': Icons.north_east,
      },
    ];

    return activities
        .map((activity) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        (activity['color'] as Color).withOpacity(0.3),
                    child: Icon(
                      activity['icon'] as IconData,
                      color: activity['type'] == 'receive'
                          ? theme.colorScheme.onSurface
                          : activity['color'] as Color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['title'] as String,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activity['date'] as String,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    activity['amount'] as String,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: (activity['amount'] as String).startsWith('+')
                          ? Colors.green
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              leading: const BackButton(),
              elevation: 0,
              backgroundColor: Colors.transparent,
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshWallet,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_account != null) ...[
                  // Header section matching Gallery-Mobile.png
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              _accountColor(theme, _account!.address)
                                  .withOpacity(0.12),
                          foregroundColor:
                              _accountColor(theme, _account!.address),
                          child: const Icon(Icons.account_circle, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _shortAddr(_account!.address),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.sync, size: 24),
                          onPressed: _refreshWallet,
                          tooltip: 'Refresh',
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 24),
                          onPressed: _openAccountManager,
                          tooltip: AppLocalizations.of(context).manageAccounts,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Quick Actions under account
                QuickActionsRow(
                  onSendTap: _handleSendTap,
                  onReceiveTap: _handleReceiveTap,
                  onBridgeTap: _handleBridgeTap,
                  showSend: FeatureFlags.on('wallet.send'),
                  showReceive: FeatureFlags.on('wallet.receive'),
                  showBridge: FeatureFlags.on('wallet.bridge'),
                ),
                const SizedBox(height: 14),

                // Balances section
                Text(
                  'Balances',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: theme.textTheme.titleMedium!.fontSize!,
                  ),
                ),
                const SizedBox(height: 16),

                // Token list
                ..._buildTokenList(theme),

                const SizedBox(height: 20),

                // Recent Activity section
                Text(
                  'Recent Activity',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: theme.textTheme.titleMedium!.fontSize!,
                  ),
                ),
                const SizedBox(height: 16),

                // Activity list
                ..._buildActivityList(theme),

                // Add some bottom padding for better scrolling experience
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
