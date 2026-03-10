import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/wallet/screens/wallet_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/background_production_settings_screen.dart';
import 'package:crypto_mobile_app/features/dapps/dapps_screen.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_screen.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/config/legacy_colors.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final int _index = 0;
  int _lastTerminalDialogAtMs = 0;
  bool _zkTerminalDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize current tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(currentHomeTabProvider.notifier).state = _index;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showPipelineStatus(ref.read(zkPassportPipelineProvider));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(
        ref
            .read(zkPassportPipelineProvider.notifier)
            .recoverPendingSessionOnForeground(),
      );
      _showPipelineStatus(ref.read(zkPassportPipelineProvider));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(zkPassportPipelineProvider, (previous, next) {
      if (!mounted) return;
      _showPipelineStatus(next);
    });

    final l10n = AppLocalizations.of(context);
    final currentNetwork = ref.watch(currentNetworkProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final index = ref.watch(currentHomeTabProvider);
    final isInternal = currentNetwork == 'internal';

    final semantic = theme.extension<AppSemanticColors>()!;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          ChallengesScreen(),
          WalletScreen(),
          DappsScreen(),
          NodeStatusScreen(),
          BackgroundProductionSettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(
        l10n, semantic, index, isInternal, isDark,
      ),
    );
  }

  Widget _buildBottomNav(
    AppLocalizations l10n,
    AppSemanticColors semantic,
    int index,
    bool isInternal,
    bool isDark,
  ) {
    final items = [
      BottomNavItem(
        icon: Symbols.cards_star_sharp,
        label: l10n.navChallenges,
        indicatorShape: NavIndicatorShape.circle,
        indicatorColor: semantic.flash.color,
        indicatorFillColor: semantic.flash.colorContainer,
      ),
      BottomNavItem(
        icon: Symbols.account_balance_wallet_sharp,
        label: l10n.navWallet,
        indicatorShape: NavIndicatorShape.circle,
        indicatorColor: semantic.flash.color,
        indicatorFillColor: semantic.flash.colorContainer,
      ),
      BottomNavItem(
        icon: Symbols.action_key_sharp,
        label: l10n.navDapps,
        indicatorShape: NavIndicatorShape.blob,
        indicatorColor: semantic.community.color,
        indicatorFillColor: semantic.community.colorContainer,
      ),
      BottomNavItem(
        icon: Symbols.check_circle_sharp,
        label: l10n.navNodeStatus,
        indicatorShape: NavIndicatorShape.hexagon,
        indicatorColor: semantic.technical.color,
        indicatorFillColor: semantic.technical.colorContainer,
      ),
      BottomNavItem(
        icon: Symbols.settings_sharp,
        label: l10n.navSettings,
        indicatorShape: NavIndicatorShape.hexagon,
        indicatorColor: semantic.technical.color,
        indicatorFillColor: semantic.technical.colorContainer,
      ),
    ];

    Widget bottomNav = BottomNav(
      items: items,
      selectedIndex: index,
      onItemSelected: (i) {
        ref.read(currentHomeTabProvider.notifier).state = i;
      },
      topBorder: !isInternal,
    );

    if (isInternal) {
      bottomNav = DecoratedBox(
        decoration: BoxDecoration(
          color: LegacyColors.getInternalNetworkBackgroundColor(isDark),
          border: Border(
            top: BorderSide(
              color: LegacyColors.getInternalNetworkBorderColor(isDark),
            ),
          ),
        ),
        child: bottomNav,
      );
    }

    return bottomNav;
  }

  void _showPipelineStatus(ZkPassportPipelineState state) {
    if (!mounted) return;

    // Do not spam progress updates. Only surface terminal success/failure states
    // in a persistent modal dialog that the user can dismiss (useful for screenshots).
    if (state.status == ZkPassportPipelineStatus.processing) {
      return;
    }
    if (state.status == ZkPassportPipelineStatus.idle) {
      return;
    }
    if (_zkTerminalDialogOpen) {
      return;
    }
    if (state.updatedAtMs <= _lastTerminalDialogAtMs) {
      return;
    }
    _lastTerminalDialogAtMs = state.updatedAtMs;
    _zkTerminalDialogOpen = true;

    final timings = <String>[
      if (state.verifyOuterMs != null)
        'Verify outer: ${state.verifyOuterMs} ms',
      if (state.wrapOuterMs != null) 'Wrap outer: ${state.wrapOuterMs} ms',
      if (state.verifyWrappedMs != null)
        'Verify wrapped: ${state.verifyWrappedMs} ms',
    ];
    final outerPublicInputs = state.outerPublicInputsHex;

    final isFailure = state.status == ZkPassportPipelineStatus.failure;
    final title = isFailure ? 'zkPassport failed' : 'zkPassport complete';

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final spacing = Theme.of(ctx).extension<AppSpacing>()!;
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.message),
                if (outerPublicInputs != null &&
                    outerPublicInputs.isNotEmpty) ...[
                  SizedBox(height: spacing.space12),
                  Text('Outer public inputs (${outerPublicInputs.length}):'),
                  SizedBox(height: spacing.space8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < outerPublicInputs.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: SelectableText(
                                '[$i] ${outerPublicInputs[i].trim()}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (timings.isNotEmpty) ...[
                  SizedBox(height: spacing.space12),
                  for (final line in timings) Text(line),
                ],
              ],
            ),
            actions: [
              Button(
                label: 'OK',
                variant: ButtonVariant.primary,
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(
                    ref
                        .read(zkPassportPipelineProvider.notifier)
                        .discardPendingSession(),
                  );
                },
              ),
            ],
          );
        },
      ).whenComplete(() {
        if (mounted) {
          _zkTerminalDialogOpen = false;
        }
      }),
    );
  }
}
