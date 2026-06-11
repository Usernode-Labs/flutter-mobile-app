import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/button.dart';

part 'button.stories.g.dart';

const meta = Meta<Button>(path: 'widgets/buttons');

final $Playground = _Story(
  name: 'Playground',
  args: _Args(
    label: StringArg('View in Leaderboard'),
    size: EnumArg(ButtonSize.regular, values: ButtonSize.values),
    variant: EnumArg(ButtonVariant.tonal, values: ButtonVariant.values),
    isLoading: BoolArg(false),
    leadingIcon: Arg.fixed(null),
    onTap: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(
      name: 'Primary',
      args: _Args(
        variant: EnumArg(ButtonVariant.primary, values: ButtonVariant.values),
      ),
    ),
    _Scenario(
      name: 'Tonal',
      args: _Args(
        variant: EnumArg(ButtonVariant.tonal, values: ButtonVariant.values),
      ),
    ),
    _Scenario(
      name: 'Outlined',
      args: _Args(
        variant: EnumArg(ButtonVariant.outlined, values: ButtonVariant.values),
      ),
    ),
    _Scenario(
      name: 'Surface',
      args: _Args(
        variant: EnumArg(ButtonVariant.surface, values: ButtonVariant.values),
      ),
    ),
    _Scenario(
      name: 'Small',
      args: _Args(size: EnumArg(ButtonSize.small, values: ButtonSize.values)),
    ),
    _Scenario(
      name: 'Large',
      args: _Args(size: EnumArg(ButtonSize.large, values: ButtonSize.values)),
    ),
    _Scenario(
      name: 'Loading',
      args: _Args(isLoading: BoolArg(true)),
    ),
  ],
);

final $WithIcon = _Story(
  name: 'With Icon',
  args: _Args(
    label: StringArg('View in Leaderboard'),
    size: EnumArg(ButtonSize.regular, values: ButtonSize.values),
    variant: EnumArg(ButtonVariant.tonal, values: ButtonVariant.values),
    isLoading: BoolArg(false),
    leadingIcon: Arg.fixed(const Icon(Symbols.leaderboard_sharp, size: 20)),
    onTap: Arg.fixed(() {}),
  ),
);

final $AllVariants = _Story(
  name: 'All Variants',
  args: _Args(label: StringArg('Button'), onTap: Arg.fixed(() {})),
  setup: (context, child, args) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final variant in ButtonVariant.values) ...[
            Text(
              variant.name.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final size in ButtonSize.values)
                  Button(
                    label: '${size.name} ${variant.name}',
                    size: size,
                    variant: variant,
                    onTap: () {},
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  },
);
