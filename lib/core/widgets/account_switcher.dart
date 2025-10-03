import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/account.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';

/// Account switcher widget for app bar
///
/// Displays current account avatar and address, allows switching accounts
class AccountSwitcher extends StatefulWidget {
  const AccountSwitcher({super.key});

  @override
  State<AccountSwitcher> createState() => _AccountSwitcherState();
}

class _AccountSwitcherState extends State<AccountSwitcher> {
  AccountMeta? _account;

  @override
  void initState() {
    super.initState();
    _loadActiveAccount();
  }

  Future<void> _loadActiveAccount() async {
    final repo = await AccountsRepository.create();
    final active = await repo.getActive();
    if (!mounted) return;
    setState(() {
      _account = active;
    });
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

  Future<void> _openAccountSelector() async {
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
        final l10n = AppLocalizations.of(ctx);
        String? selectedId = _account?.id;

        return StatefulBuilder(builder: (ctx, setStateSheet) {
          Future<void> select(String id) async {
            // Close sheet first
            if (ctx.mounted) Navigator.pop(ctx);

            // Then perform account switch
            await repo.setActiveId(id);
            final active = await repo.getActive();
            if (!mounted) return;
            setState(() => _account = active);

            // Show loading indicator while backend restarts
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${l10n.selectAccount}: ${active?.name}'),
                duration: const Duration(seconds: 1),
              ),
            );

            await RustBackendService.instance.restartForActiveAccount();
          }

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.selectAccount,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.selectAccountHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),

                // Account list
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No accounts',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  )
                else
                  ...items.map((acc) {
                    final selected = acc.id == selectedId;
                    final color = _accountColor(theme, acc.address);

                    return Card(
                      elevation: selected ? 2 : 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selected
                              ? color
                              : theme.colorScheme.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setStateSheet(() => selectedId = acc.id);
                          select(acc.id);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: color.withValues(alpha: 0.2),
                                child: Text(
                                  acc.name.isNotEmpty ? acc.name[0].toUpperCase() : 'A',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Account info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.name,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _shortAddr(acc.address),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Selected indicator
                              if (selected)
                                Icon(
                                  Icons.check_circle,
                                  color: color,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 16),

                // Manage accounts button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // TODO: Navigate to account management screen
                  },
                  icon: const Icon(Icons.settings),
                  label: Text(l10n.manageAccounts),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_account == null) {
      return const SizedBox.shrink();
    }

    final color = _accountColor(theme, _account!.address);

    return InkWell(
      onTap: _openAccountSelector,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            CircleAvatar(
              radius: 12,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Text(
                _account!.name.isNotEmpty ? _account!.name[0].toUpperCase() : 'A',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Address
            Text(
              _shortAddr(_account!.address),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),

            // Dropdown indicator
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
