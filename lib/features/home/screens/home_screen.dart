import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/wallet/screens/wallet_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/settings_screen.dart';
import 'package:crypto_mobile_app/features/dapps/dapps_screen.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenges_screen.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/home/screens/more_screen.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zk_identity/zk_identity_status_mapper.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.initialTab,
    @visibleForTesting this.debugPages,
  }) : assert(debugPages == null || debugPages.length == _homePageCount);

  /// Overrides the tier's default landing tab (see [defaultTabFor]).
  final HomeTab? initialTab;
  final List<Widget>? debugPages;

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
    // Initialize current tab. Without an explicit override the tier decides:
    // operators land on Challenges, guests and members on dApps.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final level = ref.read(userLevelProvider);
      ref.read(currentHomeTabProvider.notifier).state =
          widget.initialTab ?? defaultTabFor(level);
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
    final level = ref.watch(userLevelProvider);
    // Coerce rather than trust the stored tab: a demotion (or signing out to
    // guest) can leave the user parked on a tab their tier no longer has.
    final storedTab = ref.watch(currentHomeTabProvider);
    final tab = resolveVisibleTab(storedTab, level);
    if (tab != storedTab) {
      // Write the coercion back, not just render it. Screens listen to the raw
      // provider to decide whether they are active — Wallet's refresh timer
      // among them — so leaving it on a tab the tier cannot see would keep that
      // work running invisibly.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(currentHomeTabProvider) == storedTab) {
          ref.read(currentHomeTabProvider.notifier).state = tab;
        }
      });
    }
    final isInternal = currentNetwork == 'internal';

    final semantic = theme.extension<AppSemanticColors>()!;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: tab.index,
              children: widget.debugPages ?? homePagesFor(level),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(
        l10n,
        semantic,
        tab,
        level,
        isInternal,
      ),
    );
  }

  BottomNavItem _navItem(
    HomeTab tab,
    AppLocalizations l10n,
    AppSemanticColors semantic,
  ) {
    switch (tab) {
      case HomeTab.challenges:
        return BottomNavItem(
          icon: Symbols.cards_star_sharp,
          label: l10n.navChallenges,
          indicatorShape: NavIndicatorShape.circle,
          indicatorColor: semantic.flash.color,
          indicatorFillColor: semantic.flash.colorContainer,
        );
      case HomeTab.dapps:
        return BottomNavItem(
          icon: Symbols.action_key_sharp,
          label: l10n.navDapps,
          indicatorShape: NavIndicatorShape.blob,
          indicatorColor: semantic.community.color,
          indicatorFillColor: semantic.community.colorContainer,
        );
      case HomeTab.wallet:
        return BottomNavItem(
          icon: Symbols.account_balance_wallet_sharp,
          label: l10n.navWallet,
          indicatorShape: NavIndicatorShape.circle,
          indicatorColor: semantic.flash.color,
          indicatorFillColor: semantic.flash.colorContainer,
        );
      case HomeTab.more:
        return BottomNavItem(
          icon: Symbols.more_horiz,
          label: l10n.navMore,
          indicatorShape: NavIndicatorShape.circle,
          indicatorColor: semantic.technical.color,
          indicatorFillColor: semantic.technical.colorContainer,
        );
      case HomeTab.nodeStatus:
      case HomeTab.settings:
        // Reached through More, never rendered as a nav destination.
        throw StateError('$tab is not a bottom-nav destination');
    }
  }

  Widget _buildBottomNav(
    AppLocalizations l10n,
    AppSemanticColors semantic,
    HomeTab tab,
    UserLevel level,
    bool isInternal,
  ) {
    final tabs = visibleTabsFor(level);
    final selected = tabs.indexOf(tab);

    Widget bottomNav = BottomNav(
      items: [for (final t in tabs) _navItem(t, l10n, semantic)],
      // Settings and Node Status are shown via More, so they are not in `tabs`.
      // Highlight More while the user is on one of them.
      selectedIndex: selected == -1 ? tabs.indexOf(HomeTab.more) : selected,
      onItemSelected: (i) {
        ref.read(currentHomeTabProvider.notifier).state = tabs[i];
      },
      topBorder: !isInternal,
    );

    if (isInternal) {
      bottomNav = DecoratedBox(
        decoration: BoxDecoration(
          color: semantic.internalNetwork.colorContainer,
          border: Border(
            top: BorderSide(color: semantic.internalNetwork.color),
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
          final registration =
              ref.read(zkIdentityRegistrationProvider).valueOrNull;

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
                                ClipboardData(
                                  text: registration.nullifierHex!,
                                ),
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

/// The page for [tab], or a placeholder when [level] must not have it.
///
/// An exhaustive switch rather than a positional list: the IndexedStack indexes
/// by `HomeTab.index`, and a hand-maintained list in a second file would let a
/// reorder silently render the wrong screen.
///
/// Wallet is replaced — not merely hidden from the nav — for non-operators.
/// IndexedStack builds every child, so leaving the real WalletScreen in place
/// would keep its 5-second refresh timer and balance/transaction reads running
/// for a tier that has no on-chain account.
Widget _pageFor(HomeTab tab, UserLevel level) {
  switch (tab) {
    case HomeTab.challenges:
      return const ChallengesScreen();
    case HomeTab.wallet:
      return level == UserLevel.operator
          ? const WalletScreen()
          : const SizedBox.shrink();
    case HomeTab.dapps:
      return const DappsScreen();
    case HomeTab.nodeStatus:
      return const NodeStatusScreen();
    case HomeTab.settings:
      return const SettingsScreen();
    case HomeTab.more:
      return const MoreScreen();
  }
}

@visibleForTesting
List<Widget> homePagesFor(UserLevel level) =>
    [for (final tab in HomeTab.values) _pageFor(tab, level)];

/// Kept const for the constructor assert; `home_tabs_test.dart` pins it to
/// `HomeTab.values.length` so adding a tab cannot silently drift.
const _homePageCount = 6;
