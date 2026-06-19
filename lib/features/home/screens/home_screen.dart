import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/activity/providers/activity_providers.dart';
import 'package:crypto_mobile_app/features/activity/screens/activity_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/wallet_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/settings_screen.dart';
import 'package:crypto_mobile_app/features/dapps/dapps_screen.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_screen.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/config/legacy_colors.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zk_identity/zk_identity_status_mapper.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.initialTab = HomeTab.challenges});

  final int initialTab;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _lastTerminalDialogAtMs = 0;
  bool _zkTerminalDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize current tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(currentHomeTabProvider.notifier).state = widget.initialTab;
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
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: index,
              children: const [
                ChallengesScreen(),
                ActivityScreen(),
                WalletScreen(),
                DappsScreen(),
                NodeStatusScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(
        l10n,
        semantic,
        index,
        isInternal,
        isDark,
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
        icon: Symbols.notifications_sharp,
        label: l10n.navActivity,
        indicatorShape: NavIndicatorShape.circle,
        indicatorColor: semantic.technical.color,
        indicatorFillColor: semantic.technical.colorContainer,
        badgeCount: ref.watch(activityUnreadCountProvider),
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
      // Node status and Settings moved out of the bottom nav: node is reached
      // from the Challenges top bar, Settings from the Profile screen
      // (Fair Rewards shell, #449 / discussion #440).
    ];

    const bottomTabs = [
      HomeTab.challenges,
      HomeTab.activity,
      HomeTab.wallet,
      HomeTab.dapps,
    ];
    final selectedBottomIndex = bottomTabs.contains(index)
        ? bottomTabs.indexOf(index)
        : bottomTabs.indexOf(HomeTab.activity);

    Widget bottomNav = BottomNav(
      items: items,
      selectedIndex: selectedBottomIndex,
      onItemSelected: (i) {
        ref.read(currentHomeTabProvider.notifier).state = bottomTabs[i];
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

    // Skip dialog when pipeline was triggered from the ZK Identity challenge flow.
    if (ref.read(zkIdentityChallengeActiveProvider)) return;

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

    final isFailure = state.status == ZkPassportPipelineStatus.failure;
    final l10n = AppLocalizations.of(context);

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final spacing = Theme.of(ctx).extension<AppSpacing>()!;

          if (isFailure) {
            return AlertDialog(
              title: Text(l10n.zkIdentityResultFailureTitle),
              content: Text(l10n.zkIdentityResultFailureSubtitle),
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
          }

          // Success dialog — show status card from registration data.
          final registration = ref
              .read(zkIdentityRegistrationProvider)
              .valueOrNull;

          return AlertDialog(
            title: Text(l10n.zkIdentityResultSuccessTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.zkIdentityResultSuccessSubtitle),
                if (registration != null && registration.registered) ...[
                  SizedBox(height: spacing.space16),
                  ZkIdentityStatusCard(
                    data: buildZkIdentityStatusData(
                      registration,
                      l10n,
                      onCopyProofId: registration.nullifierHex != null
                          ? () {
                              Clipboard.setData(
                                ClipboardData(text: registration.nullifierHex!),
                              );
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Copied')),
                              );
                            }
                          : null,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              Button(
                label: 'Done',
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
