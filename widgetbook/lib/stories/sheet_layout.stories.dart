import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/sheet_layout.dart';

part 'sheet_layout.stories.g.dart';

const meta = Meta<SheetLayout>(path: 'widgets/data-display');

final $Default = _Story(
  args: _Args(
    title: StringArg('Select Network'),
    child: Arg.fixed(
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('Mainnet')),
            ListTile(title: Text('Testnet')),
            ListTile(title: Text('Devnet')),
          ],
        ),
      ),
    ),
  ),
);

final $NoTitle = _Story(
  name: 'No Title',
  args: _Args(
    title: Arg.fixed(null),
    child: Arg.fixed(
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Sheet content without a title header.'),
      ),
    ),
  ),
);
