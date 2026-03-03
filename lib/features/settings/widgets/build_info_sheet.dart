import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

/// Build info data passed from the main screen.
class BuildInfo {
  const BuildInfo({
    this.appVersion,
    this.buildNumber,
    required this.nodeVersion,
    required this.commitHash,
    required this.branch,
    required this.commitTime,
    required this.rustcVersion,
    required this.rustcChannel,
    required this.llvmVersion,
    required this.cargoTarget,
    required this.cargoFeatures,
    required this.cargoOptLevel,
    required this.cargoIsDebug,
  });

  final String? appVersion;
  final String? buildNumber;
  final String nodeVersion;
  final String commitHash;
  final String branch;
  final String commitTime;
  final String rustcVersion;
  final String rustcChannel;
  final String llvmVersion;
  final String cargoTarget;
  final String cargoFeatures;
  final String cargoOptLevel;
  final String cargoIsDebug;
}

/// Bottom sheet displaying build details in InfoRow widgets.
class BuildInfoSheet extends StatelessWidget {
  const BuildInfoSheet({
    super.key,
    required this.info,
    required this.localizations,
  });

  final BuildInfo info;
  final BuildInfoLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return SheetLayout(
      title: localizations.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App info
          if (info.appVersion != null) ...[
            InfoRow(
              label: 'App Version',
              value: info.appVersion!,
              valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
              showDivider: info.buildNumber != null,
            ),
            if (info.buildNumber != null)
              InfoRow(
                label: 'Build Number',
                value: info.buildNumber!,
                valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
                showDivider: false,
              ),
            SizedBox(height: spacing.space4),
          ],
          // Node/Rust info
          InfoRow(
            label: localizations.version,
            value: info.nodeVersion,
            valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
          ),
          InfoRow(
            label: localizations.commit,
            value: info.commitHash,
            valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
          ),
          InfoRow(
            label: localizations.branch,
            value: info.branch,
            valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
          ),
          InfoRow(
            label: localizations.commitTime,
            value: info.commitTime,
            valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
            showDivider: false,
          ),
          SizedBox(height: spacing.space4),
          InfoRow(
            label: localizations.rustc,
            value: '${info.rustcVersion} (${info.rustcChannel})',
            valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
          ),
          InfoRow(
            label: localizations.llvm,
            value: info.llvmVersion,
            valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
            showDivider: false,
          ),
          SizedBox(height: spacing.space4),
          // Cargo info
          InfoRow(
            label: localizations.cargoTarget,
            value: info.cargoTarget,
            valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
          ),
          InfoRow(
            label: localizations.features,
            value: info.cargoFeatures,
            valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
          ),
          InfoRow(
            label: localizations.optLevel,
            value: info.cargoOptLevel,
            valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
          ),
          InfoRow(
            label: localizations.debug,
            value: info.cargoIsDebug,
            valueStyle: const TextStyle(fontFamily: kMonoFontFamily),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

/// Localization strings for build info labels.
class BuildInfoLocalizations {
  const BuildInfoLocalizations({
    required this.title,
    required this.version,
    required this.commit,
    required this.branch,
    required this.commitTime,
    required this.rustc,
    required this.llvm,
    required this.cargoTarget,
    required this.features,
    required this.optLevel,
    required this.debug,
  });

  final String title;
  final String version;
  final String commit;
  final String branch;
  final String commitTime;
  final String rustc;
  final String llvm;
  final String cargoTarget;
  final String features;
  final String optLevel;
  final String debug;
}
