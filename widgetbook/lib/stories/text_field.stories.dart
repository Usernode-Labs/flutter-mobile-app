import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/text_field.dart';

part 'text_field.stories.g.dart';

const meta = Meta<DSTextField>(path: 'widgets/inputs');

final $Default = _Story(
  args: _Args(
    label: StringArg('Email'),
    hint: StringArg('Enter your email'),
    helperText: Arg.fixed(null),
    errorText: Arg.fixed(null),
    obscureText: BoolArg(false),
    readOnly: BoolArg(false),
    enabled: BoolArg(true),
    maxLines: Arg.fixed(1),
    minLines: Arg.fixed(null),
    controller: Arg.fixed(null),
    prefixIcon: Arg.fixed(null),
    suffixIcon: Arg.fixed(null),
    keyboardType: Arg.fixed(null),
    textInputAction: Arg.fixed(null),
    onChanged: Arg.fixed(null),
    onSubmitted: Arg.fixed(null),
    onTap: Arg.fixed(null),
    validator: Arg.fixed(null),
    inputFormatters: Arg.fixed(null),
    focusNode: Arg.fixed(null),
  ),
  scenarios: [
    _Scenario(
      name: 'Default',
      args: _Args(
        label: StringArg('Email'),
        hint: StringArg('Enter your email'),
        enabled: BoolArg(true),
      ),
    ),
    _Scenario(
      name: 'With Error',
      args: _Args(
        label: StringArg('Email'),
        errorText: StringArg('Invalid email address'),
      ),
    ),
    _Scenario(
      name: 'Disabled',
      args: _Args(
        label: StringArg('Wallet Address'),
        hint: StringArg('Read only'),
        enabled: BoolArg(false),
      ),
    ),
  ],
);

final $WithError = _Story(
  name: 'With Error',
  args: _Args(
    label: StringArg('Email'),
    hint: StringArg('Enter your email'),
    helperText: Arg.fixed(null),
    errorText: StringArg('Invalid email address'),
    obscureText: BoolArg(false),
    readOnly: BoolArg(false),
    enabled: BoolArg(true),
    maxLines: Arg.fixed(1),
    minLines: Arg.fixed(null),
    controller: Arg.fixed(null),
    prefixIcon: Arg.fixed(null),
    suffixIcon: Arg.fixed(null),
    keyboardType: Arg.fixed(null),
    textInputAction: Arg.fixed(null),
    onChanged: Arg.fixed(null),
    onSubmitted: Arg.fixed(null),
    onTap: Arg.fixed(null),
    validator: Arg.fixed(null),
    inputFormatters: Arg.fixed(null),
    focusNode: Arg.fixed(null),
  ),
);

final $WithIcons = _Story(
  name: 'With Icons',
  args: _Args(
    label: StringArg('Search'),
    hint: StringArg('Search transactions...'),
    helperText: Arg.fixed(null),
    errorText: Arg.fixed(null),
    obscureText: BoolArg(false),
    readOnly: BoolArg(false),
    enabled: BoolArg(true),
    maxLines: Arg.fixed(1),
    minLines: Arg.fixed(null),
    controller: Arg.fixed(null),
    prefixIcon: Arg.fixed(const Icon(Symbols.search_sharp)),
    suffixIcon: Arg.fixed(const Icon(Symbols.close_sharp)),
    keyboardType: Arg.fixed(null),
    textInputAction: Arg.fixed(null),
    onChanged: Arg.fixed(null),
    onSubmitted: Arg.fixed(null),
    onTap: Arg.fixed(null),
    validator: Arg.fixed(null),
    inputFormatters: Arg.fixed(null),
    focusNode: Arg.fixed(null),
  ),
);

final $Disabled = _Story(
  name: 'Disabled',
  args: _Args(
    label: StringArg('Wallet Address'),
    hint: StringArg('Read only'),
    helperText: Arg.fixed(null),
    errorText: Arg.fixed(null),
    obscureText: BoolArg(false),
    readOnly: BoolArg(false),
    enabled: BoolArg(false),
    maxLines: Arg.fixed(1),
    minLines: Arg.fixed(null),
    controller: Arg.fixed(null),
    prefixIcon: Arg.fixed(null),
    suffixIcon: Arg.fixed(null),
    keyboardType: Arg.fixed(null),
    textInputAction: Arg.fixed(null),
    onChanged: Arg.fixed(null),
    onSubmitted: Arg.fixed(null),
    onTap: Arg.fixed(null),
    validator: Arg.fixed(null),
    inputFormatters: Arg.fixed(null),
    focusNode: Arg.fixed(null),
  ),
);
