import 'package:flutter_test/flutter_test.dart';
import 'package:widgetbook_workspace/main.dart';

void main() {
  test('components are grouped into live app and prototype sections', () {
    final componentPaths = {
      for (final component in buildWidgetbookConfig().components)
        component.name: component.path,
    };

    expect(
      componentPaths.values,
      everyElement(anyOf(startsWith('live app/'), startsWith('prototypes/'))),
    );

    expect(componentPaths['DappsAppBarPrototype'], 'prototypes/apps');
    expect(componentPaths['ActiveChallengeBands'], 'prototypes/challenges');
    expect(componentPaths['AtomicChallengeCard'], 'prototypes/challenges');
    expect(
      componentPaths['AtomicChallengeDetailPage'],
      'prototypes/challenges',
    );
    expect(
      componentPaths['TestnetProfilePageDemo'],
      'prototypes/pages/challenges',
    );
    expect(componentPaths['WalletAppBarPrototype'], 'prototypes/apps');

    expect(componentPaths['Button'], 'live app/widgets/buttons');
    expect(componentPaths['NodeSyncDetailPage'], 'prototypes/pages/node');
    expect(componentPaths['SettingsDetailPage'], 'prototypes/pages/settings');
  });
}
