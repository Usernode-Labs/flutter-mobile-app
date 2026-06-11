import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/sheet_layout.dart';

part 'sheet_layout.stories.g.dart';

const meta = Meta<SheetLayout>(path: 'widgets/data-display');

Widget _reviewSurface(Widget child) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: 390,
      child: Material(color: Colors.transparent, child: child),
    ),
  );
}

final $Default = _Story(
  setup: (context, child, args) => _reviewSurface(child),
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
  scenarios: [
    _Scenario(
      name: 'With title',
      args: _Args.fixed(
        title: 'Select Network',
        child: Padding(
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
    _Scenario(
      name: 'Without title',
      args: _Args.fixed(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sheet content without a title header.'),
        ),
      ),
    ),
  ],
);

final $NoTitle = _Story(
  name: 'No Title',
  setup: (context, child, args) => _reviewSurface(child),
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
