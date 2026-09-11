import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/node_permissions_gate_policy.dart';

final _log = LoggingService.instance.withTag('usernode/PermissionGate');

Future<NodePermissionGateState> readNodePermissionGateState(
  SessionFeatureAccess session, {
  PlatformAlarmService? alarmService,
}) async {
  final alarms = alarmService ?? PlatformAlarmService.instance;
  if (!await alarms.initialize()) {
    throw StateError('Platform alarm service is unavailable');
  }

  final notificationsGranted = await alarms.hasNotificationsPermission();
  final hasWallet = session.identity.hasWallet;
  // Notifications are the first, unconditional gate. Do not enter the native
  // session operation runner while they are missing: Android can report the
  // activity as resumed while the device keyguard still keeps foreground
  // admission closed.
  if (!notificationsGranted) {
    return NodePermissionGateState(
      notificationsGranted: false,
      hasWallet: hasWallet,
      delegated: false,
      exactAlarmsGranted: false,
      unrestrictedBackgroundGranted: false,
    );
  }

  var delegated = false;
  if (hasWallet) {
    final delegation = await session.operations.run(
      (operation) => operation.readDelegation(),
    );
    delegated = delegation.delegated;
  }

  var exactAlarmsGranted = true;
  var unrestrictedBackgroundGranted = true;
  if (Platform.isAndroid && hasWallet && !delegated) {
    final alarmPermissions = await alarms.alarmPermissionsSnapshot();
    exactAlarmsGranted = alarmPermissions['exactAlarmGranted'] == true;
    unrestrictedBackgroundGranted =
        alarmPermissions['batteryOptDisabled'] == true;
  }

  return NodePermissionGateState(
    notificationsGranted: notificationsGranted,
    hasWallet: hasWallet,
    delegated: delegated,
    exactAlarmsGranted: exactAlarmsGranted,
    unrestrictedBackgroundGranted: unrestrictedBackgroundGranted,
  );
}

class NodePermissionsGateScreen extends StatefulWidget {
  const NodePermissionsGateScreen({
    super.key,
    required this.session,
    required this.initialState,
    required this.onSatisfied,
  });

  final SessionFeatureAccess session;
  final NodePermissionGateState initialState;
  final VoidCallback onSatisfied;

  @override
  State<NodePermissionsGateScreen> createState() =>
      _NodePermissionsGateScreenState();
}

class _NodePermissionsGateScreenState extends State<NodePermissionsGateScreen>
    with WidgetsBindingObserver {
  late NodePermissionGateState _permissionState;
  Object? _error;
  bool _busy = false;
  bool _notificationRequestRejected = false;
  int _refreshGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionState = widget.initialState;
    unawaited(_refresh());
  }

  @override
  void dispose() {
    ++_refreshGeneration;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final generation = ++_refreshGeneration;
    try {
      final value = await readNodePermissionGateState(widget.session);
      if (!mounted || generation != _refreshGeneration) return;
      _log.info(
        'Permission gate refreshed '
        '(notifications=${value.notificationsGranted}, '
        'delegated=${value.delegated}, '
        'exactAlarms=${value.exactAlarmsGranted}, '
        'unrestrictedBackground=${value.unrestrictedBackgroundGranted})',
      );
      if (value.isSatisfied) {
        widget.onSatisfied();
        return;
      }
      setState(() {
        _permissionState = value;
        _error = null;
      });
    } on SessionAdmissionClosedException {
      if (!mounted || generation != _refreshGeneration) return;
      // Android resumes Flutter before the process root has finished
      // reopening native-session admission. The root performs a forced gate
      // reconciliation after that barrier completes, so this is an expected
      // lifecycle transition rather than a user-visible failure.
      _log.debug(
        'Permission refresh deferred until foreground admission reopens',
      );
    } catch (error, stackTrace) {
      if (!mounted || generation != _refreshGeneration) return;
      _log.error(
        'Could not refresh permission gate',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() => _error = error);
    }
  }

  Future<void> _requestNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _log.info('Requesting mandatory notification permission');
      final status = await Permission.notification.request();
      _notificationRequestRejected = !status.isGranted;
      _log.info('Notification permission result: $status');
      await _refresh();
    } catch (error, stackTrace) {
      _log.error(
        'Notification permission request failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openNotificationSettings() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _log.info('Opening notification settings');
      await PlatformAlarmService.instance.openNotificationSettings();
    } catch (error, stackTrace) {
      _log.error(
        'Could not open notification settings',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestExactAlarms() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _log.info('Requesting exact-alarm permission');
      await PlatformAlarmService.instance.requestExactAlarmOnly();
      await _refresh();
    } catch (error, stackTrace) {
      _log.error(
        'Exact-alarm permission request failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBatterySettings() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _log.info('Opening unrestricted-background settings');
      await PlatformAlarmService.instance.openBatteryOptimizationSettings();
    } catch (error, stackTrace) {
      _log.error(
        'Could not open unrestricted-background settings',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delegateInstead() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.nodePermissionsDelegateTitle),
        content: Text(l10n.stakingDelegateEffect),
        actions: [
          Button(
            label: l10n.commonCancel,
            size: ButtonSize.small,
            variant: ButtonVariant.outlined,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          Button(
            label: l10n.stakingDelegateConfirm,
            size: ButtonSize.regular,
            variant: ButtonVariant.primary,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      _log.info('Delegation selected from permission gate');
      await widget.session.operations.run(
        (operation) => operation.setDelegated(true),
      );
      await _refresh();
    } catch (error, stackTrace) {
      // The policy can commit before the follow-up producer wake reports a
      // retry. Re-read before presenting the operation as failed.
      await _refresh();
      if (!mounted || _permissionState.delegated) return;
      _log.error(
        'Delegation from permission gate failed',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _permissionState.nextStep;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(AppLocalizations.of(context).nodePermissionsTitle),
        ),
        body: SafeArea(
          child: step == null
              ? const Center(child: CircularProgressIndicator())
              : _buildStep(context, step),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, NodePermissionGateStep step) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final semantic = theme.extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context);
    final producerStep = step != NodePermissionGateStep.notifications;

    final (icon, title, body, actionLabel, action) = switch (step) {
      NodePermissionGateStep.notifications => (
          Symbols.notifications_sharp,
          l10n.nodePermissionsNotificationsTitle,
          l10n.nodePermissionsNotificationsBody,
          l10n.nodePermissionsAllowNotifications,
          _requestNotifications,
        ),
      NodePermissionGateStep.exactAlarms => (
          Symbols.alarm_sharp,
          l10n.nodePermissionsExactAlarmTitle,
          l10n.nodePermissionsExactAlarmBody,
          l10n.nodePermissionsAllowExactAlarms,
          _requestExactAlarms,
        ),
      NodePermissionGateStep.unrestrictedBackground => (
          Symbols.battery_full_sharp,
          l10n.nodePermissionsBackgroundTitle,
          l10n.nodePermissionsBackgroundBody,
          l10n.nodePermissionsOpenBatterySettings,
          _openBatterySettings,
        ),
    };

    return Padding(
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          IconBadge(
            icon: icon,
            size: sizing.iconContainerXLarge,
            surfaceSize: sizing.iconContainerXLarge,
            backgroundColor: semantic.warning.colorContainer,
            iconColor: semantic.warning.onColorContainer,
          ),
          SizedBox(height: spacing.space24),
          Text(
            title,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.space12),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            SizedBox(height: spacing.space16),
            Text(
              l10n.nodePermissionsCheckFailed,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.space8),
            Center(
              child: Button(
                label: l10n.commonRetry,
                size: ButtonSize.small,
                variant: ButtonVariant.tonal,
                onTap: _busy ? null : _refresh,
              ),
            ),
          ],
          const Spacer(),
          Button(
            label: actionLabel,
            variant: ButtonVariant.primary,
            size: ButtonSize.large,
            isLoading: _busy,
            onTap: _busy ? null : action,
          ),
          if (producerStep) ...[
            SizedBox(height: spacing.space16),
            Text(
              l10n.nodePermissionsDelegateAlternative,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.space8),
            Button(
              label: l10n.nodePermissionsDelegateInstead,
              variant: ButtonVariant.outlined,
              size: ButtonSize.large,
              onTap: _busy ? null : _delegateInstead,
            ),
          ],
          if (step == NodePermissionGateStep.notifications &&
              _notificationRequestRejected) ...[
            SizedBox(height: spacing.space8),
            Button(
              label: l10n.nodePermissionsOpenNotificationSettings,
              variant: ButtonVariant.tonal,
              size: ButtonSize.large,
              onTap: _busy ? null : _openNotificationSettings,
            ),
          ],
        ],
      ),
    );
  }
}
