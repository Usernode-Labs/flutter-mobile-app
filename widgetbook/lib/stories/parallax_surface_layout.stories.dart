import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/parallax_surface_layout.dart';

part 'parallax_surface_layout.stories.g.dart';

const meta = Meta<ParallaxSurfaceLayout>(path: 'widgets/layout');

final $Default = _Story(
  args: _Args(
    header: Arg.fixed(
      const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet, size: 64, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              '1,234.56 MINA',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '\$2,469.12',
              style: TextStyle(fontSize: 16, color: Colors.white60),
            ),
          ],
        ),
      ),
    ),
    headerHeight: Arg.fixed(kScreenHeaderHeight),
    surfaceSlivers: Arg.fixed([
      SliverList.list(
        children: [
          ListTile(
            leading: Icon(Icons.arrow_upward),
            title: Text('Sent 100 MINA'),
            subtitle: Text('To B62qk...'),
            trailing: Text('-100.00'),
          ),
          ListTile(
            leading: Icon(Icons.arrow_downward),
            title: Text('Received 250 MINA'),
            subtitle: Text('From B62qm...'),
            trailing: Text('+250.00'),
          ),
          ListTile(
            leading: Icon(Icons.arrow_upward),
            title: Text('Sent 50 MINA'),
            subtitle: Text('To B62qj...'),
            trailing: Text('-50.00'),
          ),
          ListTile(
            leading: Icon(Icons.stars),
            title: Text('Block Reward'),
            subtitle: Text('Epoch 42, Slot 7'),
            trailing: Text('+720.00'),
          ),
          ListTile(
            leading: Icon(Icons.arrow_downward),
            title: Text('Received 180 MINA'),
            subtitle: Text('From B62qr...'),
            trailing: Text('+180.00'),
          ),
        ],
      ),
    ]),
    surfaceBody: Arg.fixed(null),
    nestedBody: Arg.fixed(null),
    onRefresh: Arg.fixed(null),
    onRefreshStatusChange: Arg.fixed(null),
    refreshNotificationPredicate: Arg.fixed(null),
    pinnedHeaderSliver: Arg.fixed(null),
    pinnedHeaderHeight: Arg.fixed(0.0),
    pinnedHeaderSlivers: Arg.fixed(null),
    pinnedHeadersHeight: Arg.fixed(0.0),
    surfacePinnedSlivers: Arg.fixed(null),
    surfacePinnedHeight: Arg.fixed(0.0),
    scrollFractionNotifier: Arg.fixed(null),
    surfaceFillsViewport: Arg.fixed(false),
    controller: Arg.fixed(null),
    headerFadesOnScroll: Arg.fixed(true),
    showEdgeFade: Arg.fixed(false),
    safeAreaOverlay: Arg.fixed(true),
    headerOverlay: Arg.fixed(null),
    title: StringArg('Wallet'),
  ),
  scenarios: [
    _Scenario(
      name: 'Default Layout',
      args: _Args.fixed(
        header: const Center(
          child: Text(
            'Wallet',
            style: TextStyle(fontSize: 28, color: Colors.white),
          ),
        ),
        title: 'Wallet',
        headerFadesOnScroll: true,
        showEdgeFade: false,
      ),
    ),
    _Scenario(
      name: 'With Edge Fade',
      args: _Args.fixed(
        header: const Center(
          child: Text(
            'Wallet',
            style: TextStyle(fontSize: 28, color: Colors.white),
          ),
        ),
        title: 'Wallet',
        showEdgeFade: true,
      ),
    ),
  ],
);

final $WithTitle = _Story(
  name: 'With Pinned Title',
  args: _Args(
    header: Arg.fixed(
      const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard, size: 64, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'Leaderboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
    headerHeight: Arg.fixed(kDefaultHeaderHeight),
    surfaceSlivers: Arg.fixed([
      SliverList.list(
        children: [
          for (var i = 1; i <= 20; i++)
            ListTile(
              leading: CircleAvatar(child: Text('$i')),
              title: Text('Participant $i'),
              trailing: Text('${(21 - i) * 1000} pts'),
            ),
        ],
      ),
    ]),
    surfaceBody: Arg.fixed(null),
    nestedBody: Arg.fixed(null),
    onRefresh: Arg.fixed(null),
    onRefreshStatusChange: Arg.fixed(null),
    refreshNotificationPredicate: Arg.fixed(null),
    pinnedHeaderSliver: Arg.fixed(null),
    pinnedHeaderHeight: Arg.fixed(0.0),
    pinnedHeaderSlivers: Arg.fixed(null),
    pinnedHeadersHeight: Arg.fixed(0.0),
    surfacePinnedSlivers: Arg.fixed(null),
    surfacePinnedHeight: Arg.fixed(0.0),
    scrollFractionNotifier: Arg.fixed(null),
    surfaceFillsViewport: Arg.fixed(false),
    controller: Arg.fixed(null),
    headerFadesOnScroll: Arg.fixed(true),
    showEdgeFade: Arg.fixed(true),
    safeAreaOverlay: Arg.fixed(true),
    headerOverlay: Arg.fixed(null),
    title: StringArg('Leaderboard'),
  ),
);
