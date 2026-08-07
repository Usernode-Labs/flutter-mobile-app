import 'package:flutter_test/flutter_test.dart';
import 'package:widgetbook_workspace/main.dart';

void main() {
  test('all components live under the live app section', () {
    final componentPaths = {
      for (final component in buildWidgetbookConfig().components)
        component.name: component.path,
    };

    // The prototype sections (testnet challenges/leaderboard/profile UI)
    // were retired with the thin-shell migration — SV owns those surfaces
    // now. Everything that remains is live-app DS inventory.
    expect(componentPaths.values, everyElement(startsWith('live app/')));

    expect(componentPaths['Button'], 'live app/widgets/buttons');
    expect(componentPaths['ChallengeCard'], 'live app/widgets/challenges');
    expect(componentPaths['ZkIdentityFlowPage'], 'live app/pages/zk-identity');
  });
}
