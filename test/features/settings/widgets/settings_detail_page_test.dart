import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/settings/widgets/settings_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  Widget buildApp(Widget child) {
    final textTheme = ThemeData.light().textTheme;
    final cieTheme = ColorIsExpensiveTheme(textTheme);
    final themeData = cieTheme.light().copyWith(
          extensions: DesignSystemTheme.standardExtensions(
            semanticColors: AppSemanticColors.light(),
          ),
        );

    return MaterialApp(theme: themeData, home: child);
  }

  testWidgets('renders settings detail page content', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const SettingsDetailPage(
          title: 'Settings',
          status: SettingsDetailStatusData(
            label: 'Permissions',
            headline: 'All Good',
            tone: SettingsDetailStatusTone.allGood,
            rows: [
              SettingsDetailRowData.status(
                icon: Symbols.alarm_sharp,
                title: 'Exact alarms',
                statusLabel: 'Enabled',
                statusVariant: StatusBadgeVariant.success,
              ),
            ],
          ),
          sections: [
            SettingsDetailSectionData(
              title: 'General',
              rows: [
                SettingsDetailRowData.navigation(
                  icon: Symbols.palette_sharp,
                  title: 'Appearance',
                  valueLabel: 'System',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('All Good'), findsOneWidget);
    expect(find.text('Exact alarms'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('forwards toggle changes', (tester) async {
    var enabled = true;

    await tester.pumpWidget(
      buildApp(
        SettingsDetailPage(
          title: 'Settings',
          status: const SettingsDetailStatusData(
            label: 'Permissions',
            headline: 'All Good',
            tone: SettingsDetailStatusTone.allGood,
          ),
          sections: [
            SettingsDetailSectionData(
              title: 'General',
              rows: [
                SettingsDetailRowData.toggle(
                  icon: Symbols.bedtime_sharp,
                  title: 'Sleep On Inactivity',
                  switchValue: enabled,
                  onSwitchChanged: (value) => enabled = value,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(enabled, false);
  });

  testWidgets('aligns section row badges with section titles', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const SettingsDetailPage(
          title: 'Settings',
          status: SettingsDetailStatusData(
            label: 'Permissions',
            headline: 'All Good',
            tone: SettingsDetailStatusTone.allGood,
          ),
          sections: [
            SettingsDetailSectionData(
              title: 'General',
              rows: [
                SettingsDetailRowData.navigation(
                  icon: Symbols.palette_sharp,
                  title: 'Appearance',
                  valueLabel: 'System',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final headerLeft = tester.getTopLeft(find.text('General')).dx;
    final badgeLeft = tester.getTopLeft(find.byType(IconBadge)).dx;

    expect((badgeLeft - headerLeft).abs(), lessThan(0.1));
  });

  testWidgets('aligns status row badges with status copy', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const SettingsDetailPage(
          title: 'Settings',
          status: SettingsDetailStatusData(
            label: 'Permissions',
            headline: 'All Good',
            tone: SettingsDetailStatusTone.allGood,
            rows: [
              SettingsDetailRowData.status(
                icon: Symbols.alarm_sharp,
                title: 'Exact alarms',
                statusLabel: 'Enabled',
                statusVariant: StatusBadgeVariant.success,
              ),
            ],
          ),
          sections: [],
        ),
      ),
    );

    final labelLeft = tester.getTopLeft(find.text('Permissions')).dx;
    final badgeLeft = tester.getTopLeft(find.byType(IconBadge)).dx;

    expect((badgeLeft - labelLeft).abs(), lessThan(0.1));
  });
}
