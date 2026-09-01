import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/top_app_bar.dart';

part 'top_app_bar.stories.g.dart';

const meta = Meta<TopAppBar>(path: 'live app/widgets/navigation');

final $Small = _Story(
  name: 'Small',
  args: _Args(
    title: StringArg('Details'),
    size: EnumArg(TopAppBarSize.small, values: TopAppBarSize.values),
    onLeadingTap: Arg.fixed(() {}),
    actions: Arg.fixed([
      IconButton(onPressed: () {}, icon: const Icon(Symbols.more_vert_sharp)),
    ]),
  ),
  scenarios: [
    _Scenario(
      name: 'Small',
      args: _Args(
        size: EnumArg(TopAppBarSize.small, values: TopAppBarSize.values),
      ),
    ),
    _Scenario(
      name: 'Large',
      args: _Args(
        size: EnumArg(TopAppBarSize.large, values: TopAppBarSize.values),
      ),
    ),
  ],
  setup: (context, child, args) {
    return Material(
      child: CustomScrollView(
        slivers: [
          child,
          const SliverFillRemaining(
            child: Center(child: Text('Scroll content area')),
          ),
        ],
      ),
    );
  },
);

final $Large = _Story(
  name: 'Large',
  args: _Args(
    title: StringArg('Block Production'),
    size: EnumArg(TopAppBarSize.large, values: TopAppBarSize.values),
    subtitle: Arg.fixed('Mar 1 – Mar 31 · Technical'),
    onLeadingTap: Arg.fixed(() {}),
    actions: Arg.fixed([
      IconButton(onPressed: () {}, icon: const Icon(Symbols.share_sharp)),
    ]),
  ),
  setup: (context, child, args) {
    return Material(
      child: CustomScrollView(
        slivers: [
          child,
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ListTile(title: Text('Item $index')),
              childCount: 30,
            ),
          ),
        ],
      ),
    );
  },
);
