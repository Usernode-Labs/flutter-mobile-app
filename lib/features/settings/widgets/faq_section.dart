import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

/// Localization strings needed by the FAQ section.
class FaqLocalizations {
  const FaqLocalizations({
    required this.whatIsTitle,
    required this.whatIsDescription,
    required this.step1Title,
    required this.step1Desc,
    required this.step2Title,
    required this.step2Desc,
    required this.step3Title,
    required this.step3Desc,
    required this.step4Title,
    required this.step4Desc,
    required this.platformAndroidTitle,
    required this.platformIosTitle,
    required this.platformAndroidDesc,
    required this.platformIosDesc,
    required this.reliabilityByMode,
    required this.defaultMode,
    required this.defaultReliability,
    required this.defaultDesc,
    required this.keepAliveMode,
    required this.keepAliveReliability,
    required this.keepAliveDesc,
    required this.iosKeepAliveReliability,
    required this.iosKeepAliveDesc,
    required this.backgroundOnly,
    required this.backgroundOnlyReliability,
    required this.backgroundOnlyDesc,
  });

  final String whatIsTitle;
  final String whatIsDescription;
  final String step1Title;
  final String step1Desc;
  final String step2Title;
  final String step2Desc;
  final String step3Title;
  final String step3Desc;
  final String step4Title;
  final String step4Desc;
  final String platformAndroidTitle;
  final String platformIosTitle;
  final String platformAndroidDesc;
  final String platformIosDesc;
  final String reliabilityByMode;
  final String defaultMode;
  final String defaultReliability;
  final String defaultDesc;
  final String keepAliveMode;
  final String keepAliveReliability;
  final String keepAliveDesc;
  final String iosKeepAliveReliability;
  final String iosKeepAliveDesc;
  final String backgroundOnly;
  final String backgroundOnlyReliability;
  final String backgroundOnlyDesc;
}

/// Tier 3: Help & Info FAQ section with 4 ExpansionTiles.
class FaqSection extends StatelessWidget {
  const FaqSection({
    super.key,
    required this.localizations,
    this.deviceManufacturer,
  });

  final FaqLocalizations localizations;
  final String? deviceManufacturer;

  static const _aboutText =
      'Your device is part of a new network. It verifies, executes, and '
      'contributes compute directly to the network, passively in the '
      'background - with no central servers, no hidden infra. As long as users '
      'keep the app running, the network will continue to operate, peer to '
      'peer, with no external dependencies.\n\n'
      'We\'re doing this to enable networks that can be hosted end-to-end by '
      'their own communities - both for decentralization, and to enable a '
      'natural coordination point around participation, where users who help '
      'operate and contribute to systems directly realize the benefits from '
      'it.\n\n'
      'Right now we are in testnet as we validate the core layer: block '
      'production, consensus behavior, and network reliability. As these '
      'stabilize, we\'ll build upon the unique features of the platform - its '
      'decentralization, zero knowledge proofs, and sybil-resistant identity - '
      'to introduce new activities, coordination mechanisms, and tools for '
      'self-hosted, sybil-resistant communities.\n\n'
      'Thanks for helping test at this early stage. The app right now is '
      'simple, but as we prove out the core functionality, we hope to make '
      'possible a new kind of community-owned network, where users can '
      'directly run and benefit from the networks they use.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Help & Info',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: spacing.space8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                _buildAboutTile(context),
                _buildHowItWorksTile(context),
                _buildPlatformTile(context),
                _buildVrfTile(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;

    return ExpansionTile(
      title: Text('About', style: theme.textTheme.bodyLarge),
      childrenPadding: EdgeInsets.fromLTRB(
        spacing.space16,
        0,
        spacing.space16,
        spacing.space16,
      ),
      children: [
        Text(
          _aboutText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorksTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;

    return ExpansionTile(
      title: Text(localizations.whatIsTitle, style: theme.textTheme.bodyLarge),
      childrenPadding: EdgeInsets.fromLTRB(
        spacing.space16,
        0,
        spacing.space16,
        spacing.space16,
      ),
      children: [
        Text(
          localizations.whatIsDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        SizedBox(height: spacing.space16),
        _NumberedStep(
            number: '1',
            title: localizations.step1Title,
            description: localizations.step1Desc),
        SizedBox(height: spacing.space12),
        _NumberedStep(
            number: '2',
            title: localizations.step2Title,
            description: localizations.step2Desc),
        SizedBox(height: spacing.space12),
        _NumberedStep(
            number: '3',
            title: localizations.step3Title,
            description: localizations.step3Desc),
        SizedBox(height: spacing.space12),
        _NumberedStep(
            number: '4',
            title: localizations.step4Title,
            description: localizations.step4Desc),
      ],
    );
  }

  Widget _buildPlatformTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    return ExpansionTile(
      title: Text(
        'Platform & Reliability',
        style: theme.textTheme.bodyLarge,
      ),
      childrenPadding: EdgeInsets.fromLTRB(
        spacing.space16,
        0,
        spacing.space16,
        spacing.space16,
      ),
      children: [
        Text(
          isAndroid
              ? localizations.platformAndroidDesc
              : localizations.platformIosDesc,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        SizedBox(height: spacing.space16),
        Container(
          padding: EdgeInsets.all(spacing.space12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: radii.borderRadiusSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.reliabilityByMode,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacing.space12),
              if (isAndroid) ...[
                _ReliabilityRow(
                  mode: localizations.defaultMode,
                  percentage: localizations.defaultReliability,
                  description: localizations.defaultDesc,
                  color: semantic.success.color,
                ),
                SizedBox(height: spacing.space8),
                _ReliabilityRow(
                  mode: localizations.keepAliveMode,
                  percentage: localizations.keepAliveReliability,
                  description: localizations.keepAliveDesc,
                  color: semantic.technical.color,
                ),
              ] else ...[
                _ReliabilityRow(
                  mode: localizations.keepAliveMode,
                  percentage: localizations.iosKeepAliveReliability,
                  description: localizations.iosKeepAliveDesc,
                  color: semantic.success.color,
                ),
                SizedBox(height: spacing.space8),
                _ReliabilityRow(
                  mode: localizations.backgroundOnly,
                  percentage: localizations.backgroundOnlyReliability,
                  description: localizations.backgroundOnlyDesc,
                  color: semantic.warning.color,
                ),
              ],
            ],
          ),
        ),
        if (isAndroid && deviceManufacturer != null) ...[
          SizedBox(height: spacing.space12),
          Row(
            children: [
              Icon(
                Symbols.smartphone_sharp,
                size: sizing.iconXSmall,
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: spacing.space8),
              Text(
                'Device: $deviceManufacturer',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildVrfTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;

    return ExpansionTile(
      title: Text(
        'Understanding VRF & Slots',
        style: theme.textTheme.bodyLarge,
      ),
      childrenPadding: EdgeInsets.fromLTRB(
        spacing.space16,
        0,
        spacing.space16,
        spacing.space16,
      ),
      children: [
        Text(
          'What is VRF?',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: spacing.space8),
        Text(
          'VRF (Verifiable Random Function) is how the network fairly selects '
          'block producers. At the start of each epoch, the network runs VRF '
          'calculations to determine which validators will produce blocks in '
          'upcoming slots.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        SizedBox(height: spacing.space16),
        Text(
          'VRF Status Meanings',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: spacing.space8),
        _StatusExplanation(
          status: 'Pending',
          description: 'Waiting for epoch transition to start calculations',
          color: colorScheme.outline,
        ),
        SizedBox(height: spacing.space8),
        _StatusExplanation(
          status: 'Calculating',
          description: 'VRF evaluation in progress (takes a few hours)',
          color: semantic.warning.color,
        ),
        SizedBox(height: spacing.space8),
        _StatusExplanation(
          status: 'Complete',
          description: 'Slot assignments are finalized and scheduled',
          color: semantic.success.color,
        ),
        SizedBox(height: spacing.space16),
        Text(
          'What is a "Won Slot"?',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: spacing.space8),
        Text(
          'When VRF selects your node to produce a block at a specific time, '
          'you\'ve "won" that slot. Your responsibility is to have your device '
          'awake and connected so the block can be produced.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        SizedBox(height: spacing.space16),
        Container(
          padding: EdgeInsets.all(spacing.space12),
          decoration: BoxDecoration(
            color: semantic.warning.colorContainer,
            borderRadius: radii.borderRadiusSmall,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Symbols.timer_sharp,
                size: sizing.iconSmall,
                color: semantic.warning.color,
              ),
              SizedBox(width: spacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why Timing Matters',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: semantic.warning.color,
                      ),
                    ),
                    SizedBox(height: spacing.space4),
                    Text(
                      'Each slot has a ~5-seconds window. If your device '
                      'doesn\'t wake up in time or loses network connectivity, '
                      'the slot is missed and counted as "failed."',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: sizing.iconRegular,
          height: sizing.iconRegular,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: radii.borderRadiusMedium,
          ),
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SizedBox(width: spacing.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacing.space4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReliabilityRow extends StatelessWidget {
  const _ReliabilityRow({
    required this.mode,
    required this.percentage,
    required this.description,
    required this.color,
  });

  final String mode;
  final String percentage;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.space8,
            vertical: spacing.space4,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: radii.borderRadiusXSmall,
          ),
          child: Text(
            percentage,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
        SizedBox(width: spacing.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusExplanation extends StatelessWidget {
  const _StatusExplanation({
    required this.status,
    required this.description,
    required this.color,
  });

  final String status;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: EdgeInsets.only(top: spacing.space8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: spacing.space12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '$status: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
