import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/metrics/presentation/controllers/metrics_config_provider.dart';
import 'package:crypto_mobile_app/features/metrics/domain/services/metrics_reporting_service.dart';

class MetricsSettingsScreen extends ConsumerWidget {
  const MetricsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(metricsConfigProvider);
    final stats = MetricsReportingService.instance.getStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metrics Status'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Configuration Card (Read-only)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings),
                      const SizedBox(width: 8),
                      Text(
                        'Configuration',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildConfigRow(
                    'Status',
                    config.enabled ? 'Enabled' : 'Disabled',
                    config.enabled ? Colors.green : Colors.grey,
                  ),
                  _buildConfigRow(
                    'Endpoint',
                    config.apiMetricsEndpoint.isNotEmpty
                        ? config.apiMetricsEndpoint
                        : 'Not configured',
                    config.apiMetricsEndpoint.isNotEmpty
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  _buildConfigRow(
                    'Interval',
                    '${config.intervalSeconds} seconds',
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Configuration is managed via environment variables',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Stats Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart),
                      const SizedBox(width: 8),
                      Text(
                        'Statistics',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow('Status',
                      stats['is_running'] as bool ? 'Running' : 'Stopped'),
                  _buildStatRow('Success Count', '${stats['success_count']}'),
                  _buildStatRow('Failure Count', '${stats['failure_count']}'),
                  _buildStatRow('Success Rate', '${stats['success_rate']}'),
                  if (stats['last_report_time'] != null)
                    _buildStatRow(
                        'Last Report', stats['last_report_time'] as String),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: MetricsReportingService.instance.isRunning
                            ? () async {
                                await MetricsReportingService.instance
                                    .reportNow();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Metrics sent manually'),
                                    ),
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.send),
                        label: const Text('Send Now'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          MetricsReportingService.instance.resetStats();
                          // Trigger rebuild to show reset stats
                          (context as Element).markNeedsBuild();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Stats'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 8),
                      Text(
                        'About Metrics',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Metrics collected:\n'
                    '• Node status and sync state\n'
                    '• Device and app information\n'
                    '• Battery and network status\n'
                    '• Blockchain and peer data\n'
                    '• Background task performance\n\n'
                    'Configuration:\n'
                    'Metrics are configured via environment variables '
                    '(METRICS_ENABLED, METRICS_ENDPOINT, METRICS_INTERVAL). '
                    'The app must be rebuilt to change these settings.\n\n'
                    'All metrics are sent securely to the configured endpoint. '
                    'Failed reports are dropped (no retry).',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
