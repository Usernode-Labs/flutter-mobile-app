import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

class ProducedBlockDetailsScreen extends StatelessWidget {
  const ProducedBlockDetailsScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final epoch = (args?['epoch'] as int?) ?? 0;
    final slot = (args?['slot'] as int?) ?? 0;
    final slotsInEpoch = (args?['slotsInEpoch'] as int?) ?? 0;
    final meta = args?['metadata'] as Map<String, dynamic>?;

    // Calculate global slot: globalSlot = epoch * slotsInEpoch + slot
    final globalSlot = epoch * slotsInEpoch + slot;

    return Scaffold(
      appBar: AppBar(
        title: Text('Produced block at slot $slot ($globalSlot)'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space16),
          child: Builder(
            builder: (context) {
              if (meta == null) {
                return Center(
                  child: Text(
                    'No metadata available for this slot.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final theme = Theme.of(context);
              final blockHash = meta['blockHash']?.toString() ?? '';
              final tokensWon = meta['tokensWon']?.toString() ?? '';
              final canonical = meta['canonical'] == true;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Epoch $epoch · Slot $slot (Global $globalSlot)',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  SizedBox(height: spacing.space16),
                  Text(
                    'Block hash',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  SizedBox(height: spacing.space4),
                  SelectableText(
                    blockHash,
                    style: theme.textTheme.bodyMedium,
                  ),
                  SizedBox(height: spacing.space16),
                  Text(
                    'Tokens won',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  SizedBox(height: spacing.space4),
                  Text(
                    tokensWon,
                    style: theme.textTheme.bodyMedium,
                  ),
                  SizedBox(height: spacing.space16),
                  Text(
                    'Canonical',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  SizedBox(height: spacing.space4),
                  Text(
                    canonical ? 'Yes' : 'No',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
