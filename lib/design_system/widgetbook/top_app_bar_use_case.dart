import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/top_app_bar.dart';

WidgetbookComponent topAppBarComponent() {
  return WidgetbookComponent(
    name: 'TopAppBar',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final title = context.knobs.string(
            label: 'Title',
            initialValue: 'Leaderboard',
          );

          final isLarge = context.knobs.boolean(
            label: 'Large variant',
            initialValue: false,
          );

          final showSubtitle = context.knobs.boolean(
            label: 'Show subtitle',
            initialValue: true,
          );

          final showImage = context.knobs.boolean(
            label: 'Show image',
            initialValue: true,
          );

          final colors = Theme.of(context).colorScheme;

          return CustomScrollView(
            slivers: [
              TopAppBar(
                title: title,
                size: isLarge ? TopAppBarSize.large : TopAppBarSize.small,
                subtitle: isLarge && showSubtitle
                    ? 'Technical · Jan 12 - Jan 30'
                    : null,
                image: isLarge && showImage
                    ? Container(
                        color: colors.primaryContainer,
                        child: Icon(
                          Symbols.hexagon_sharp,
                          color: colors.primary,
                        ),
                      )
                    : null,
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ListTile(
                    title: Text('Item ${index + 1}'),
                    subtitle: Text('Subtitle for item ${index + 1}'),
                  ),
                  childCount: 20,
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}
