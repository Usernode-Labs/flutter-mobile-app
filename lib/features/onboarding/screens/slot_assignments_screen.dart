import 'package:flutter/material.dart';

class SlotAssignmentsScreen extends StatelessWidget {
  const SlotAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slot Assignments'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header KPI card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Epoch 176',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Evaluated 650 / 720',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ProgressBar(progress: 650 / 720),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // List title
              Text(
                'Assignments',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // List of slots (placeholder data)
              Expanded(
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final slot = 520 + index;
                    final produced = index % 4 != 3; // some missed
                    return _SlotRow(
                      icon: Icons.layers,
                      title: 'Global Slot $slot',
                      subtitle: 'Expected 10:${(index * 3) % 60}'.padRight(2, '0'),
                      status: produced ? 'Evaluated' : 'Pending',
                      trailing: produced ? 'Won' : '—',
                      produced: produced,
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final track = Colors.grey.shade300;
    final p = progress.clamp(0.0, 1.0);
    return SizedBox(
      height: 12,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          FractionallySizedBox(
            widthFactor: p,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 4,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.trailing,
    required this.produced,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final String trailing;
  final bool produced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(icon, color: theme.colorScheme.onSurface)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '$status • $subtitle',
                    style:
                        theme.textTheme.bodyMedium?.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}


