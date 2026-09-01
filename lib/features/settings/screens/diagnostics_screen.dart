import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/perf/providers/perf_benchmark_provider.dart';
import 'package:crypto_mobile_app/features/settings/widgets/build_info_sheet.dart';
import 'package:crypto_mobile_app/features/settings/widgets/diagnostics_settings_section.dart';

/// Minimal native diagnostics surface for the thin shell: device benchmark,
/// HTTP debug logs, and build info. All user settings live in the SV web
/// settings modal; this screen only carries native-only tooling, reachable
/// from the SV debug escape hatch or `openNativeScreen('diagnostics')`.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  String _shortCommit(String hash) =>
      hash.length >= 7 ? hash.substring(0, 7) : hash;

  String get _buildInfoSubtitle {
    final env = ref.read(buildEnvProvider);
    final sc = _shortCommit(env.git.commitHash);
    if (_packageInfo != null) {
      return 'v${_packageInfo!.version} \u00b7 $sc';
    }
    return sc;
  }

  void _showBuildInfo() {
    final env = ref.read(buildEnvProvider);
    final l10n = AppLocalizations.of(context);
    final shortCommit = _shortCommit(env.git.commitHash);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BuildInfoSheet(
        info: BuildInfo(
          appVersion: _packageInfo?.version,
          buildNumber: _packageInfo?.buildNumber,
          nodeVersion: env.version,
          commitHash: shortCommit,
          branch: env.git.branch,
          commitTime: env.git.commitTime,
          rustcVersion: env.rustc.version,
          rustcChannel: env.rustc.channel,
          llvmVersion: env.rustc.llvmVersion,
          cargoTarget: env.cargo.target,
          cargoFeatures: env.cargo.features,
          cargoOptLevel: env.cargo.optLevel.toString(),
          cargoIsDebug: env.cargo.isDebug.toString(),
        ),
        localizations: BuildInfoLocalizations(
          title: l10n.settingsBuildInfo,
          appVersion: l10n.buildInfoAppVersion,
          buildNumber: l10n.buildInfoBuildNumber,
          version: l10n.buildInfoVersion,
          commit: l10n.buildInfoCommit,
          branch: l10n.buildInfoBranch,
          commitTime: l10n.buildInfoCommitTime,
          rustc: l10n.buildInfoRustc,
          llvm: l10n.buildInfoLlvm,
          cargoTarget: l10n.buildInfoCargoTarget,
          features: l10n.buildInfoFeatures,
          optLevel: l10n.buildInfoOptLevel,
          debug: l10n.buildInfoDebug,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final l10n = AppLocalizations.of(context);
    final debugModeEnabled = ref.watch(debugModeProvider);
    final perfState = ref.watch(perfBenchmarkProvider);
    final hasCurrentBenchmarkRun = perfState.isStartingRun ||
        perfState.isRunning ||
        (perfState.activeRunId != null && !perfState.hasFinishedRun);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsDiagnostics)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: spacing.space16),
          children: [
            SizedBox(height: spacing.space16),
            DiagnosticsSettingsSection(
              onDeviceBenchmarkTap: () => context.push(
                hasCurrentBenchmarkRun
                    ? AppRoutes.deviceBenchmarkRun
                    : AppRoutes.deviceBenchmark,
              ),
              debugModeEnabled: debugModeEnabled,
              onDebugModeChanged: (value) =>
                  ref.read(debugModeProvider.notifier).set(value),
              onHttpLogsTap: () => context.push(AppRoutes.httpDebugLogs),
            ),
            SizedBox(height: spacing.space24),
            ListSectionHeader(title: l10n.settingsAbout),
            Card(
              child: ListTile(
                leading: const Icon(Symbols.info_sharp),
                title: Text(l10n.settingsBuildInfo),
                subtitle: Text(_buildInfoSubtitle),
                trailing: Icon(
                  Symbols.chevron_right_sharp,
                  size: sizing.iconSmall,
                ),
                onTap: _showBuildInfo,
              ),
            ),
            SizedBox(height: spacing.space32),
          ],
        ),
      ),
    );
  }
}
