import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/parallax_surface_layout.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent parallaxSurfaceLayoutComponent() {
  return WidgetbookComponent(
    name: 'ParallaxSurfaceLayout',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground (surfaceBody)',
        builder: (context) {
          final headerHeight = context.knobs.double.slider(
            label: 'Header height',
            initialValue: kDefaultHeaderHeight,
            min: 100,
            max: 400,
          );
          final hasRefresh = context.knobs.boolean(
            label: 'RefreshIndicator',
            initialValue: true,
          );
          final headerFades = context.knobs.boolean(
            label: 'headerFadesOnScroll',
          );
          final edgeFade = context.knobs.boolean(
            label: 'showEdgeFade',
          );

          return Scaffold(
            body: SafeArea(
              child: ParallaxSurfaceLayout(
                headerHeight: headerHeight,
                onRefresh: hasRefresh
                    ? () => Future.delayed(const Duration(seconds: 1))
                    : null,
                header: const _MockHeader(),
                // ignore: deprecated_member_use_from_same_package
                surfaceBody: const _MockSurface(),
                headerFadesOnScroll: headerFades,
                showEdgeFade: edgeFade,
              ),
            ),
          );
        },
      ),
      WidgetbookUseCase(
        name: 'Slivers',
        builder: (context) {
          final headerHeight = context.knobs.double.slider(
            label: 'Header height',
            initialValue: kDefaultHeaderHeight,
            min: 100,
            max: 400,
          );
          final headerFades = context.knobs.boolean(
            label: 'headerFadesOnScroll',
          );
          final edgeFade = context.knobs.boolean(
            label: 'showEdgeFade',
          );
          final itemCount = context.knobs.double
              .slider(
                label: 'Item count',
                initialValue: 30,
                min: 5,
                max: 100,
              )
              .toInt();

          return Scaffold(
            body: SafeArea(
              child: ParallaxSurfaceLayout(
                headerHeight: headerHeight,
                header: const _MockHeader(),
                headerFadesOnScroll: headerFades,
                showEdgeFade: edgeFade,
                surfaceSlivers: [
                  SliverList.builder(
                    itemCount: itemCount,
                    itemBuilder: (context, i) => ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text('Lazy Item ${i + 1}'),
                      subtitle: const Text('Built on demand via SliverList'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}

class _MockHeader extends StatelessWidget {
  const _MockHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Balance',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: spacing.space8),
        Text('1,234,567', style: theme.textTheme.displaySmall),
        SizedBox(height: spacing.space4),
        Text(
          'Last checked at 14:32',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MockSurface extends StatelessWidget {
  const _MockSurface();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        20,
        (i) => ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text('Item ${i + 1}'),
          subtitle: const Text('Subtitle text'),
        ),
      ),
    );
  }
}
