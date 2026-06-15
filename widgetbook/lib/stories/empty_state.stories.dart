import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/empty_state.dart';

part 'empty_state.stories.g.dart';

const meta = Meta<EmptyState>(path: 'live app/widgets/indicators');

final $Default = _Story(
  args: _Args(
    icon: Arg.fixed(Symbols.inbox_sharp),
    title: StringArg('No transactions yet'),
    subtitle: Arg.fixed('Your transactions will appear here.'),
  ),
  scenarios: [
    _Scenario(
      name: 'Without action',
      args: _Args.fixed(
        icon: Symbols.inbox_sharp,
        title: 'No transactions yet',
        subtitle: 'Your transactions will appear here.',
      ),
    ),
    _Scenario(
      name: 'With action',
      args: _Args.fixed(
        icon: Symbols.search_sharp,
        title: 'No results found',
        subtitle: 'Try adjusting your filters.',
        action: ElevatedButton(
          onPressed: () {},
          child: const Text('Clear Filters'),
        ),
      ),
    ),
    _Scenario(
      name: 'Minimal',
      args: _Args.fixed(title: 'Nothing here'),
    ),
  ],
);

final $WithAction = _Story(
  name: 'With Action',
  args: _Args(
    icon: Arg.fixed(Symbols.search_sharp),
    title: StringArg('No results found'),
    subtitle: Arg.fixed('Try adjusting your filters.'),
    action: Arg.fixed(
      ElevatedButton(onPressed: () {}, child: const Text('Clear Filters')),
    ),
  ),
);

final $Minimal = _Story(
  name: 'Minimal',
  args: _Args(title: StringArg('Nothing here')),
);
