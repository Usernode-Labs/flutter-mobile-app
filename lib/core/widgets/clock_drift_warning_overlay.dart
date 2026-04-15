import 'dart:async';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:flutter/material.dart';

enum _ClockDriftSeverity { warning, critical }

class _ClockDriftWarningData {
  const _ClockDriftWarningData({
    required this.driftMs,
    required this.severity,
  });

  final int driftMs;
  final _ClockDriftSeverity severity;
}

class ClockDriftWarningOverlay extends StatefulWidget {
  const ClockDriftWarningOverlay({super.key});

  @override
  State<ClockDriftWarningOverlay> createState() =>
      _ClockDriftWarningOverlayState();
}

class _ClockDriftWarningOverlayState extends State<ClockDriftWarningOverlay>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 10);

  Timer? _refreshTimer;
  bool _refreshInFlight = false;
  int? _displayedDriftMs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      return;
    }
    _stopPolling();
  }

  void _startPolling() {
    if (_refreshTimer != null) return;
    unawaited(_refreshClockDrift());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(_refreshClockDrift());
    });
  }

  void _stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refreshClockDrift() async {
    if (_refreshInFlight) return;
    if (!RustBackendService.instance.isRunning) {
      if (!mounted || _displayedDriftMs == null) return;
      setState(() {
        _displayedDriftMs = null;
      });
      return;
    }

    _refreshInFlight = true;
    try {
      final resolvedDriftMs =
          await RustBackendService.instance.resolveNodeClockDriftMs();
      if (!mounted) return;
      setState(() {
        _displayedDriftMs = resolvedDriftMs;
      });
    } finally {
      _refreshInFlight = false;
    }
  }

  _ClockDriftWarningData? _warningDataForDrift(int? driftMs) {
    if (driftMs == null) return null;

    final absoluteDriftMs = driftMs.abs();
    if (absoluteDriftMs > 10000) {
      return _ClockDriftWarningData(
        driftMs: driftMs,
        severity: _ClockDriftSeverity.critical,
      );
    }
    if (absoluteDriftMs > 5000) {
      return _ClockDriftWarningData(
        driftMs: driftMs,
        severity: _ClockDriftSeverity.warning,
      );
    }
    return null;
  }

  String _formatDriftLabel(AppLocalizations l10n, int driftMs) {
    final seconds = (driftMs.abs() / 1000).toStringAsFixed(1);
    if (driftMs >= 0) {
      return l10n.clockDriftAhead(seconds);
    }
    return l10n.clockDriftBehind(seconds);
  }

  Future<void> _showClockDriftDialog(
    BuildContext context,
    AppLocalizations l10n,
    int driftMs,
  ) async {
    final driftLabel = _formatDriftLabel(l10n, driftMs);
    final spacing =
        Theme.of(context).extension<AppSpacing>() ?? AppSpacing.standard();
    final dialogContext = appNavigatorKey.currentContext ?? context;

    await showDialog<void>(
      context: dialogContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.clockDriftWarningTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.clockDriftWarningBody(driftLabel)),
              SizedBox(height: spacing.space12),
              Text(l10n.clockDriftWarningInstruction),
              SizedBox(height: spacing.space16),
              Text(
                l10n.clockDriftRecommendationTitle,
                style: Theme.of(dialogContext).textTheme.titleSmall,
              ),
              SizedBox(height: spacing.space8),
              Text(l10n.clockDriftRecommendationBody),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.clockDriftDismiss),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing =
        Theme.of(context).extension<AppSpacing>() ?? AppSpacing.standard();
    final radii =
        Theme.of(context).extension<AppRadii>() ?? AppRadii.standard();
    final warning = _warningDataForDrift(_displayedDriftMs);
    if (warning == null) {
      return const SizedBox.shrink();
    }

    final backgroundColor = warning.severity == _ClockDriftSeverity.critical
        ? Colors.red.shade900
        : Colors.amber.shade700;
    final foregroundColor = warning.severity == _ClockDriftSeverity.critical
        ? Colors.white
        : Colors.black;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + spacing.space12,
      right: spacing.space12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radii.borderRadiusFull,
          onTap: () => _showClockDriftDialog(
            context,
            l10n,
            warning.driftMs,
          ),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: radii.borderRadiusFull,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
