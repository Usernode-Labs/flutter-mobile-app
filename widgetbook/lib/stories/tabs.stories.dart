import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/tabs.dart';

part 'tabs.stories.g.dart';

const meta = Meta<Tabs>(path: 'widgets/navigation');

final $Default = _Story(
  name: 'Default',
  args: _Args(
    tabs: Arg.fixed(const [
      TabItem(label: 'Active', badgeCount: 3),
      TabItem(label: 'Completed'),
      TabItem(label: 'Missed'),
    ]),
    children: Arg.fixed(const [
      Center(child: Text('Active challenges content')),
      Center(child: Text('Completed challenges content')),
      Center(child: Text('Missed challenges content')),
    ]),
    initialIndex: IntArg(0),
    isScrollable: BoolArg(false),
    showDivider: BoolArg(true),
    onTabChanged: Arg.fixed(null),
  ),
  scenarios: [
    _Scenario(
      name: 'Three Tabs',
      args: _Args.fixed(
        tabs: const [
          TabItem(label: 'Active', badgeCount: 3),
          TabItem(label: 'Completed'),
          TabItem(label: 'Missed'),
        ],
        children: const [
          Center(child: Text('Active challenges content')),
          Center(child: Text('Completed challenges content')),
          Center(child: Text('Missed challenges content')),
        ],
        initialIndex: 0,
        showDivider: true,
      ),
    ),
    _Scenario(
      name: 'Second Tab Selected',
      args: _Args.fixed(
        tabs: const [
          TabItem(label: 'Active', badgeCount: 3),
          TabItem(label: 'Completed'),
          TabItem(label: 'Missed'),
        ],
        children: const [
          Center(child: Text('Active challenges content')),
          Center(child: Text('Completed challenges content')),
          Center(child: Text('Missed challenges content')),
        ],
        initialIndex: 1,
      ),
    ),
    _Scenario(
      name: 'Scrollable',
      args: _Args.fixed(
        tabs: const [
          TabItem(label: 'Active', badgeCount: 3),
          TabItem(label: 'Completed'),
          TabItem(label: 'Missed'),
        ],
        children: const [
          Center(child: Text('Active challenges content')),
          Center(child: Text('Completed challenges content')),
          Center(child: Text('Missed challenges content')),
        ],
        isScrollable: true,
      ),
    ),
    _Scenario(
      name: 'No Divider',
      args: _Args.fixed(
        tabs: const [
          TabItem(label: 'Active', badgeCount: 3),
          TabItem(label: 'Completed'),
          TabItem(label: 'Missed'),
        ],
        children: const [
          Center(child: Text('Active challenges content')),
          Center(child: Text('Completed challenges content')),
          Center(child: Text('Missed challenges content')),
        ],
        showDivider: false,
      ),
    ),
  ],
);
