import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

const _serverDelegateAddress =
    'B62qiTKpEPjGTSHZrtM8uXiKgn8So916pLmNJKDhKeyBQL9TDb3nvBG';

class StakingDelegationScreen extends StatefulWidget {
  const StakingDelegationScreen({
    super.key,
    required this.session,
  });

  final SessionFeatureAccess session;

  @override
  State<StakingDelegationScreen> createState() =>
      _StakingDelegationScreenState();
}

class _StakingDelegationScreenState extends State<StakingDelegationScreen> {
  bool _submitting = false;
  bool _showSuccess = false;
  SessionDelegationSnapshot? _delegation;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.session.operations.run(
        (operation) => operation.readDelegation(),
      );
      if (!mounted) return;
      setState(() {
        _delegation = value;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _delegate() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final value = await widget.session.operations.run(
        (operation) => operation.setDelegated(true),
      );
      if (!mounted) return;
      _delegation = value;
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).stakingDelegateError),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _showSuccess = true;
    });
  }

  Future<void> _undelegate() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.stakingUndelegateTitle),
        content: Text(l10n.stakingUndelegateBody),
        actions: [
          Button(
            label: l10n.commonCancel,
            size: ButtonSize.small,
            variant: ButtonVariant.outlined,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          Button(
            label: l10n.stakingUndelegateConfirm,
            size: ButtonSize.regular,
            variant: ButtonVariant.primary,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await widget.session.operations.run(
        (operation) => operation.setDelegated(false),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.stakingUndelegateError)));
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final delegated = _delegation?.delegated == true;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !_showSuccess,
        title: Text(
          _showSuccess
              ? l10n.stakingDelegationActiveTitle
              : l10n.stakingManagerTitle,
        ),
      ),
      body: SafeArea(
        child: _loadError != null
            ? Center(
                child: Button(
                  label: l10n.commonRetry,
                  onTap: _load,
                ),
              )
            : _delegation == null
                ? const Center(child: CircularProgressIndicator())
                : _showSuccess
                    ? _buildSuccess(context)
                    : delegated
                        ? _buildDelegated(context)
                        : _buildReview(context),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.stakingDelegateIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing.space16),
          _serverCard(context, selected: true),
          SizedBox(height: spacing.space16),
          Text(
            l10n.stakingDelegateEffect,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing.space8),
          Text(
            l10n.stakingDelegateNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Button(
            label: _submitting
                ? l10n.stakingDelegating
                : l10n.stakingDelegateConfirm,
            variant: ButtonVariant.primary,
            size: ButtonSize.large,
            isLoading: _submitting,
            onTap: _delegate,
          ),
          SizedBox(height: spacing.space16),
        ],
      ),
    );
  }

  Widget _buildDelegated(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          IconBadge(
            icon: Symbols.groups_sharp,
            size: sizing.iconContainerXLarge,
            surfaceSize: sizing.iconContainerXLarge,
          ),
          SizedBox(height: spacing.space16),
          Text(
            l10n.stakingDelegationActiveTitle,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.space8),
          Text(
            l10n.stakingDelegationActiveBody(l10n.stakingServerName),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.space24),
          _serverCard(context),
          const Spacer(),
          Button(
            label: l10n.stakingUndelegateConfirm,
            variant: ButtonVariant.outlined,
            size: ButtonSize.large,
            isLoading: _submitting,
            onTap: _undelegate,
          ),
          SizedBox(height: spacing.space16),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final semantic = theme.extension<AppSemanticColors>()!;
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        children: [
          const Spacer(),
          IconBadge(
            icon: Symbols.check_sharp,
            size: sizing.iconContainerXLarge,
            surfaceSize: sizing.iconContainerXLarge,
            backgroundColor: semantic.success.colorContainer,
            iconColor: semantic.success.onColorContainer,
          ),
          SizedBox(height: spacing.space16),
          Text(
            l10n.stakingDelegationActiveTitle,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.space8),
          Text(
            l10n.stakingDelegationActiveBody(l10n.stakingServerName),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: Button(
              label: l10n.stakingDone,
              variant: ButtonVariant.primary,
              size: ButtonSize.large,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serverCard(BuildContext context, {bool selected = false}) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return AppCard(
      bordered: true,
      color: colors.surfaceContainerLowest,
      padding: EdgeInsets.symmetric(vertical: spacing.space8),
      child: ListTile(
        leading: const IconBadge(icon: Symbols.dns_sharp),
        title: Text(l10n.stakingServerName),
        subtitle: Text(
          _shortenAddress(
            _delegation?.delegateAddress ?? _serverDelegateAddress,
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: kMonoFontFamily,
            color: colors.onSurfaceVariant,
          ),
        ),
        trailing: selected
            ? Icon(Symbols.check_circle_sharp, color: colors.primary)
            : null,
      ),
    );
  }
}

String _shortenAddress(String address) {
  const head = 8;
  const tail = 6;
  if (address.length <= head + tail) return address;
  return '${address.substring(0, head)}…${address.substring(address.length - tail)}';
}
