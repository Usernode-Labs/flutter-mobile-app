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

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late WalletService _walletService;
  late WalletBalance _balance;
  late List<TransactionModel> _transactions;
  bool _isLoading = false;
  AccountMeta? _account;
  bool _accountExpanded =
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
          Color _accountColor(ThemeData theme, String addr) {
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
            controller.text = 'Imported ${items.length + 1}';
            await showDialog(
              context: ctx,
              builder: (dctx) {
                String? err;
                return StatefulBuilder(builder: (dctx, setStateDialog) {
                  return AlertDialog(
                    title: const Text('Import with seed phrase'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                                labelText: 'Account name'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: seedCtrl,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Seed phrase (space-separated words)',
                            ),
                          ),
                          if (err != null) ...[
                            const SizedBox(height: 8),
                            Text(err!,
                                style: TextStyle(
                                    color: Theme.of(dctx).colorScheme.error)),
                          ]
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dctx),
                          child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () async {
                          final name = controller.text.trim().isEmpty
                              ? 'Imported'
                              : controller.text.trim();
                          final phrase = seedCtrl.text
                              .trim()
                              .toLowerCase()
                              .replaceAll(RegExp(r'\s+'), ' ');
                          if (phrase.isEmpty) {
                            setStateDialog(() => err = 'Seed phrase required');
                            return;
                          }
                          if (!bip39.validateMnemonic(phrase)) {
                            setStateDialog(
                                () => err = 'Invalid BIP39 seed phrase');
                            return;
                          }
                          final res = await (await AccountsRepository.create())
                              .importFromMnemonic(
                            name: name,
                            mnemonic: phrase,
                          );
                          if (res == null) {
                            setStateDialog(
                                () => err = 'Failed to import account');
                            return;
                          }
                          if (mounted) {
                            Navigator.pop(dctx);
                            Navigator.pop(ctx);
                            _loadActiveAccount();
                          }
                        },
                        child: const Text('Import'),
                      )
                    ],
                  );
                });
              },
            );
          }

          Future<void> importWithPrivateKey() async {
            controller.text = 'Imported ${items.length + 1}';
            await showDialog(
              context: ctx,
              builder: (dctx) {
                String? err;
                return StatefulBuilder(builder: (dctx, setStateDialog) {
                  return AlertDialog(
                    title: const Text('Import with private key'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                                labelText: 'Account name'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: keyCtrl,
                            decoration: const InputDecoration(
                              labelText:
                                  'Private key (hex) — 64 chars, optional 0x prefix',
                            ),
                          ),
                          if (err != null) ...[
                            const SizedBox(height: 8),
                            Text(err!,
                                style: TextStyle(
                                    color: Theme.of(dctx).colorScheme.error)),
                          ]
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dctx),
                          child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () async {
                          final name = controller.text.trim().isEmpty
                              ? 'Imported'
                              : controller.text.trim();
                          var pk = keyCtrl.text.trim();
                          if (pk.isEmpty) {
                            setStateDialog(() => err = 'Private key required');
                            return;
                          }
                          if (pk.startsWith('0x')) pk = pk.substring(2);
                          final isHex64 =
                              RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(pk);
                          if (!isHex64) {
                            setStateDialog(
                                () => err = 'Invalid private key format');
                            return;
                          }
                          final res = await (await AccountsRepository.create())
                              .importFromPrivateKey(
                            name: name,
                            privateKey: pk,
                          );
                          if (res == null) {
                            setStateDialog(
                                () => err = 'Failed to import account');
                            return;
                          }
                          if (mounted) {
                            Navigator.pop(dctx);
                            Navigator.pop(ctx);
                            _loadActiveAccount();
                          }
                        },
                        child: const Text('Import'),
                      )
                    ],
                  );
                });
              },
            );
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
                                          _accountColor(theme, acc.address)
                                              .withOpacity(0.12),
                                      foregroundColor:
                                          _accountColor(theme, acc.address),
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
                              backgroundColor: theme.colorScheme.error.withOpacity(0.12),
                              foregroundColor: theme.colorScheme.error,
                              child: const Icon(Icons.delete_forever),
                            ),
                            title: const Text('Delete all accounts (dev)'),
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: ctx,
                                builder: (dctx) => AlertDialog(
                                  title: const Text('Delete all accounts?'),
                                  content: const Text('This will remove all stored accounts on this device.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(dctx, true),
                                      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await (await AccountsRepository.create()).deleteAll();
                                if (mounted) {
                                  setState(() => _account = null);
                                  Navigator.of(ctx).pop();
                                  // ignore: use_build_context_synchronously
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AccountOnboardingScreen(),
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
    // For now, derive holdings from the single balance; can be extended later
    return [
      TokenHolding(
        name: _balance.tokenSymbol,
        symbol: _balance.tokenSymbol,
        amount: _balance.tokenAmount,
        usdValue: _balance.usdValue,
        icon: Icons.monetization_on_outlined,
      ),
    ];
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
                  Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              _accountColor(theme, _account!.address)
                                  .withOpacity(0.12),
                          foregroundColor:
                              _accountColor(theme, _account!.address),
                          child: const Icon(Icons.account_circle_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _account!.name,
                                style: theme.textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _shortAddr(_account!.address),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 22),
                          tooltip: 'Copy address',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _account!.address));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Address copied')),
                            );
                          },
                          visualDensity:
                              const VisualDensity(horizontal: -4, vertical: -4),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                        IconButton(
                          tooltip: 'Manage accounts',
                          icon: const Icon(Icons.settings_outlined, size: 22),
                          onPressed: _openAccountManager,
                          visualDensity:
                              const VisualDensity(horizontal: -4, vertical: -4),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                const SizedBox(height: 16),

                // Wallet Balance Card
                // Balances Header
                Text(
                  'Balances',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                WalletBalanceCard(
                  balance: _balance,
                  holdings: _topHoldingsFromBalance(),
                  address: _account?.address,
                  publicKey: _account?.publicKey,
                ),

                const SizedBox(height: 20),

                if (FeatureFlags.on('wallet.transactions')) ...[
                  // Recent Transactions Header
                  Text(
                    'Recent Transactions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Transaction List
                  TransactionsList(
                    transactions: _transactions,
                    onTransactionTap: _handleTransactionTap,
                  ),
                ],

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
