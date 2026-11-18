import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:data_registration/demo/demo_data_store.dart';
import 'package:data_registration/main.dart';
import 'package:data_registration/utils/responsive.dart';

void main() {
  testWidgets('Home screen renders on phone and desktop widths', (
    tester,
  ) async {
    for (final size in const [Size(320, 640), Size(1920, 1080)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      expect(find.text('Manage Tables'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    tester.view.reset();
  });

  test('breakpoints', () {
    expect(screenSizeForWidth(390), ScreenSize.compact);
    expect(screenSizeForWidth(820), ScreenSize.medium);
    expect(screenSizeForWidth(1440), ScreenSize.expanded);
    expect(gridColumnsForWidth(390), 1);
    expect(gridColumnsForWidth(1200), 3);
  });

  test('demo store is seeded', () async {
    final tables = await DemoDataStore.instance.getTables();
    expect(tables.length, 4);
    expect(await DemoDataStore.instance.getItems(tables.first.id!), isNotEmpty);
  });
}
