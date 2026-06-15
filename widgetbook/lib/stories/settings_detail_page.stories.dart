import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/settings/widgets/settings_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

part 'settings_detail_page.stories.g.dart';

const meta = Meta<SettingsDetailPage>(path: 'prototypes/pages/settings');

final _allGoodStatus = SettingsDetailStatusData(
  label: 'Permissions',
  headline: 'All Good',
  tone: SettingsDetailStatusTone.allGood,
  description: 'Background production is ready on this device.',
  rows: [
    SettingsDetailRowData.status(
      icon: Symbols.alarm_sharp,
      title: 'Exact alarms',
      subtitle: 'Required for block timing',
      statusLabel: 'Enabled',
      statusVariant: StatusBadgeVariant.success,
      onTap: () {},
    ),
    SettingsDetailRowData.status(
      icon: Symbols.battery_saver_sharp,
      title: 'Battery optimization',
      subtitle: 'Usernode can keep scheduled work reliable',
      statusLabel: 'Ready',
      statusVariant: StatusBadgeVariant.success,
      onTap: () {},
    ),
  ],
);

final _attentionStatus = SettingsDetailStatusData(
  label: 'Permissions',
  headline: 'Action Needed',
  tone: SettingsDetailStatusTone.attention,
  description:
      'One system setting needs attention before background production.',
  rows: [
    SettingsDetailRowData.status(
      icon: Symbols.alarm_sharp,
      title: 'Exact alarms',
      subtitle: 'Required for block timing',
      statusLabel: 'Enabled',
      statusVariant: StatusBadgeVariant.success,
      onTap: () {},
    ),
    SettingsDetailRowData.action(
      icon: Symbols.battery_saver_sharp,
      title: 'Battery optimization',
      subtitle: 'Disable battery restrictions for reliable wakeups',
      actionLabel: 'Fix',
      onTap: () {},
    ),
  ],
);

final _sections = [
  SettingsDetailSectionData(
    title: 'General',
    rows: [
      SettingsDetailRowData.navigation(
        icon: Symbols.palette_sharp,
        title: 'Appearance',
        valueLabel: 'System',
        onTap: () {},
      ),
      SettingsDetailRowData.toggle(
        icon: Symbols.bedtime_sharp,
        title: 'Sleep On Inactivity',
        subtitle: 'Avoid unnecessary battery and bandwidth use',
        switchValue: true,
        onSwitchChanged: (_) {},
      ),
      SettingsDetailRowData.navigation(
        icon: Symbols.info_sharp,
        title: 'Build Info',
        subtitle: 'v0.3.1 · a1b2c3d',
        onTap: () {},
      ),
    ],
  ),
  SettingsDetailSectionData(
    title: 'Diagnostics',
    rows: [
      SettingsDetailRowData.navigation(
        icon: Symbols.speed_sharp,
        title: 'Device Benchmark',
        subtitle: 'Run on-device performance measurements',
        onTap: () {},
      ),
      SettingsDetailRowData.toggle(
        icon: Symbols.bug_report_sharp,
        title: 'Debug Mode',
        subtitle: 'Off · no network logging',
        switchValue: false,
        onSwitchChanged: (_) {},
      ),
      SettingsDetailRowData.navigation(
        icon: Symbols.terminal_sharp,
        title: 'HTTP Logs',
        subtitle: 'View captured network requests',
        onTap: () {},
      ),
    ],
  ),
  SettingsDetailSectionData(
    title: 'Help & Info',
    rows: [
      SettingsDetailRowData.navigation(
        icon: Symbols.info_sharp,
        title: 'About',
        subtitle: 'Background block production and reliability',
        onTap: () {},
      ),
      SettingsDetailRowData.navigation(
        icon: Symbols.casino_sharp,
        title: 'VRF slots',
        subtitle: 'How slot assignments are calculated',
        onTap: () {},
      ),
    ],
  ),
];

final $AllGood = _Story(
  name: 'All Good',
  args: _Args(
    title: StringArg('Settings'),
    status: Arg.fixed(_allGoodStatus),
    sections: Arg.fixed(_sections),
    onBackTap: Arg.fixed(() {}),
    onSettingsTap: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(
      name: 'All Good',
      args: _Args.fixed(
        title: 'Settings',
        status: _allGoodStatus,
        sections: _sections,
        onBackTap: () {},
        onSettingsTap: () {},
      ),
    ),
    _Scenario(
      name: 'Action Needed',
      args: _Args.fixed(
        title: 'Settings',
        status: _attentionStatus,
        sections: _sections,
        onBackTap: () {},
        onSettingsTap: () {},
      ),
    ),
  ],
);

final $ActionNeeded = _Story(
  name: 'Action Needed',
  args: _Args(
    title: StringArg('Settings'),
    status: Arg.fixed(_attentionStatus),
    sections: Arg.fixed(_sections),
    onBackTap: Arg.fixed(() {}),
    onSettingsTap: Arg.fixed(() {}),
  ),
);
