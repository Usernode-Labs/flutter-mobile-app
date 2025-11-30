import 'package:flutter/material.dart';

class ProducedBlockDetailsScreen extends StatelessWidget {
  const ProducedBlockDetailsScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  Widget build(BuildContext context) {
    final epoch = (args?['epoch'] as int?) ?? 0;
    final slot = (args?['slot'] as int?) ?? 0;
    final meta = args?['metadata'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Text('Produced block at slot $slot'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
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
                    'Epoch $epoch · Slot $slot',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Block hash',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    blockHash,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tokens won',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tokensWon,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Canonical',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: 4),
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


