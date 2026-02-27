import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/tabs.dart';

WidgetbookComponent tabsComponent() {
  return WidgetbookComponent(
    name: 'Tabs',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final isScrollable = context.knobs.boolean(
            label: 'Scrollable',
            initialValue: false,
          );

          final tabCount = context.knobs.int.slider(
            label: 'Tab count',
            initialValue: 3,
            min: 2,
            max: 6,
          );

          final showDivider = context.knobs.boolean(
            label: 'Show divider',
            initialValue: true,
          );

          final showBadges = context.knobs.boolean(
            label: 'Show badges',
            initialValue: true,
          );

          final labels = [
            'Active',
            'Completed',
            'Missed',
            'Pending',
            'Archived',
            'Draft',
          ];
          final badges = [2, 1, 0, 5, 0, 3];

          final tabs = List.generate(
            tabCount,
            (i) => TabItem(
              label: labels[i],
              badgeCount: showBadges ? badges[i] : null,
            ),
          );

          final children = List.generate(
            tabCount,
            (i) => Center(
              child: Text(
                '${labels[i]} content',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          );

          return SizedBox(
            height: 400,
            child: Tabs(
              tabs: tabs,
              isScrollable: isScrollable,
              showDivider: showDivider,
              children: children,
            ),
          );
        },
      ),
    ],
  );
}
