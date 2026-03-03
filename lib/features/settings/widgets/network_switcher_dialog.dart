import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

class NetworkSwitcherDialog extends StatefulWidget {
  final String currentNetwork;

  const NetworkSwitcherDialog({super.key, required this.currentNetwork});

  @override
  State<NetworkSwitcherDialog> createState() => _NetworkSwitcherDialogState();
}

class _NetworkSwitcherDialogState extends State<NetworkSwitcherDialog> {
  late String selectedNetwork;

  @override
  void initState() {
    super.initState();
    selectedNetwork = widget.currentNetwork;
  }

  String _formatUrl(String url) {
    return url.replaceFirst(RegExp(r'^https?://'), '');
  }

  Widget _buildUrlRow(
      String label, String url, ThemeData theme, ColorScheme colorScheme) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Padding(
      padding: EdgeInsets.only(left: spacing.space24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              url,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: kMonoFontFamily,
                fontSize: 11,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkOption({
    required String networkType,
    required String displayName,
    required String description,
    required bool isSelected,
    required bool isCurrentlyActive,
    required String genesisUrl,
    required String seedlistUrl,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required AppSemanticColors semantic,
  }) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedNetwork = networkType;
        });
      },
      child: Container(
        padding: EdgeInsets.all(spacing.space12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: radii.borderRadiusSmall,
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Symbols.radio_button_checked_sharp
                      : Symbols.radio_button_unchecked_sharp,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: sizing.iconSmall,
                ),
                SizedBox(width: spacing.space8),
                Text(
                  displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isCurrentlyActive) ...[
                  SizedBox(width: spacing.space8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.space8,
                      vertical: spacing.space4,
                    ),
                    decoration: BoxDecoration(
                      color: semantic.success.colorContainer,
                      borderRadius: radii.borderRadiusXSmall,
                    ),
                    child: Text(
                      'Active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: semantic.success.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: spacing.space4),
            Padding(
              padding: EdgeInsets.only(left: spacing.space24),
              child: Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(height: spacing.space8),
            _buildUrlRow('Genesis', _formatUrl(genesisUrl), theme, colorScheme),
            SizedBox(height: spacing.space4),
            _buildUrlRow(
                'Seedlist', _formatUrl(seedlistUrl), theme, colorScheme),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Network Switcher'),
          IconButton(
            icon: const Icon(Symbols.close_sharp),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SELECT NETWORK',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: spacing.space12),
            _buildNetworkOption(
              networkType: 'testnet',
              displayName: 'Testnet',
              description: 'Default network',
              isSelected: selectedNetwork == 'testnet',
              isCurrentlyActive: widget.currentNetwork == 'testnet',
              genesisUrl: AppConfig.testnetGenesisUrl,
              seedlistUrl: AppConfig.testnetSeedlistUrl,
              theme: theme,
              colorScheme: colorScheme,
              semantic: semantic,
            ),
            SizedBox(height: spacing.space12),
            _buildNetworkOption(
              networkType: 'internal',
              displayName: 'Internal',
              description: 'Development network',
              isSelected: selectedNetwork == 'internal',
              isCurrentlyActive: widget.currentNetwork == 'internal',
              genesisUrl: AppConfig.internalGenesisUrl,
              seedlistUrl: AppConfig.internalSeedlistUrl,
              theme: theme,
              colorScheme: colorScheme,
              semantic: semantic,
            ),
            SizedBox(height: spacing.space12),
            _buildNetworkOption(
              networkType: 'custom',
              displayName: 'Custom',
              description: 'static.usernodelabs.org/custom',
              isSelected: selectedNetwork == 'custom',
              isCurrentlyActive: widget.currentNetwork == 'custom',
              genesisUrl: AppConfig.customGenesisUrl,
              seedlistUrl: AppConfig.customSeedlistUrl,
              theme: theme,
              colorScheme: colorScheme,
              semantic: semantic,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: selectedNetwork == widget.currentNetwork
              ? null
              : () => Navigator.of(context).pop(selectedNetwork),
          child: Text(selectedNetwork == widget.currentNetwork
              ? 'No Change'
              : 'Switch Network'),
        ),
      ],
    );
  }
}
