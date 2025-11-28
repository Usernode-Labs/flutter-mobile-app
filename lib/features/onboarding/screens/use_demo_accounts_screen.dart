import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/features/wallet/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';

class UseDemoAccountsScreen extends ConsumerStatefulWidget {
  const UseDemoAccountsScreen({super.key});

  @override
  ConsumerState<UseDemoAccountsScreen> createState() =>
      _UseDemoAccountsScreenState();
}

class _UseDemoAccountsScreenState extends ConsumerState<UseDemoAccountsScreen> {
  List<DemoAccountPreview> _demoAccounts = [];
  bool _loading = true;
  bool _importing = false;
  int? _importingIndex;

  @override
  void initState() {
    super.initState();
    _loadDemoAccounts();
  }

  Future<void> _loadDemoAccounts() async {
    setState(() => _loading = true);

    try {
      final demoAccounts = AppConfig.demoAccounts;
      final previews = <DemoAccountPreview>[];

      for (int i = 0; i < demoAccounts.length; i++) {
        final account = demoAccounts[i];
        previews.add(DemoAccountPreview(
          index: i + 1,
          privateKey: account.secretKeyHex,
          expectedPublicKey: account.publicKeyHex,
          expectedBech32Address: account.publicKeyHashBech32m,
          amount: account.amount,
          tier: account.tier,
        ));
      }

      setState(() {
        _demoAccounts = previews;
        _loading = false;
      });
    } catch (e) {
      LoggingService.instance.error(
        'Failed to load demo accounts',
        tag: 'DEMO_ACCOUNTS',
        error: e,
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _importDemoAccount(DemoAccountPreview account) async {
    if (_importing) return;

    setState(() {
      _importing = true;
      _importingIndex = account.index;
    });

    try {
      // Derive keys from private key
      final accountExport = accountFromPrivateKey(
        privateKeyHex: account.privateKey,
      );

      // Validate that generated keys match expected keys
      if (accountExport.publicKeyHex != account.expectedPublicKey) {
        if (!mounted) return;
        setState(() {
          _importing = false;
          _importingIndex = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).demoKeyValidationFailedPublicKey(account.tier),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        LoggingService.instance.error(
          'Public key mismatch: expected ${account.expectedPublicKey}, got ${accountExport.publicKeyHex}',
          tag: 'DEMO_ACCOUNTS',
        );
        return;
      }

      if (accountExport.publicKeyHashBech32M != account.expectedBech32Address) {
        if (!mounted) return;
        setState(() {
          _importing = false;
          _importingIndex = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).demoKeyValidationFailedAddress(account.tier),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        LoggingService.instance.error(
          'Address mismatch: expected ${account.expectedBech32Address}, got ${accountExport.publicKeyHashBech32M}',
          tag: 'DEMO_ACCOUNTS',
        );
        return;
      }

      LoggingService.instance.debug(
        'Demo account keys validated successfully',
        tag: 'DEMO_ACCOUNTS',
      );

      // Import the validated account
      final repo = await AccountsRepository.create();
      final result = await repo.importFromPrivateKey(
        name: 'Demo ${account.tier.toUpperCase()} ${account.index}',
        privateKeyHex: account.privateKey,
        isDemo: true,
      );

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _importing = false;
          _importingIndex = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).demoImportFailed),
          ),
        );
        return;
      }

      LoggingService.instance.debug(
        'Demo account imported successfully',
        tag: 'DEMO_ACCOUNTS',
      );

      // Invalidate provider to update router state
      ref.invalidate(hasAnyAccountProvider);

      // Start backend for new account
      try {
        await RustBackendService.instance.startNode();
      } catch (e) {
        LoggingService.instance.error(
          'Failed to start backend',
          tag: 'DEMO_ACCOUNTS',
          error: e,
        );
      }

      // Navigate to main app
      if (!mounted) return;
      context.go('/main/node');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importingIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).demoImportFailedWithError(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppAppBar(
        title: l10n.onboardingUseDemoAccount,
        showNodeStatus: false,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _demoAccounts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.demoNoDemoAccountsAvailable,
                            style: theme.textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.demoNotConfigured,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.demoSelectToImport,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.science_outlined,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    l10n.demoWarning,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _demoAccounts.length,
                          itemBuilder: (context, index) {
                            final account = _demoAccounts[index];
                            final isImporting =
                                _importingIndex == account.index;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Text(
                                    '${account.index}',
                                    style: TextStyle(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        account.tierDisplay,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        account.formattedBalance,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: isImporting
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : FilledButton(
                                        onPressed: _importing
                                            ? null
                                            : () => _importDemoAccount(account),
                                        child: Text(l10n.demoUseButton),
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
}

class DemoAccountPreview {
  final int index;
  final String privateKey;
  final String expectedPublicKey;
  final String expectedBech32Address;
  final int amount;
  final String tier;

  DemoAccountPreview({
    required this.index,
    required this.privateKey,
    required this.expectedPublicKey,
    required this.expectedBech32Address,
    required this.amount,
    required this.tier,
  });

  String get formattedBalance {
    // Convert from base units to millions (divide by 1,000,000)
    final millions = amount / 1000000;
    if (millions >= 1000) {
      // Convert millions to billions
      final billions = millions / 1000;
      return '${billions.toStringAsFixed(0)}B TKN';
    } else {
      return '${millions.toStringAsFixed(0)}M TKN';
    }
  }

  String get tierEmoji {
    switch (tier.toLowerCase()) {
      case 'foundation':
        return '👑';
      case 'whale':
        return '🐋';
      case 'fish':
        return '🐟';
      default:
        return '📦';
    }
  }

  String get tierDisplay => '$tierEmoji ${tier.toUpperCase()}';
}
