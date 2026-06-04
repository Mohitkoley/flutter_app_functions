import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app_functions/flutter_app_functions.dart';
import 'package:flutter_app_functions_example/main.dart';

void main() {
  testWidgets('simulates an agent tool call that mutates app state', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterAppFunctions.instance.unregisterAll();

    try {
      final store = DemoProductivityStore();
      registerProductivityAppFunctions(store);

      await tester.pumpWidget(MyApp(store: store));

      expect(find.text('Agent AppFunctions MCP Hub'), findsOneWidget);
      expect(
        find.textContaining('AppFunctions background listener active'),
        findsOneWidget,
      );
      expect(find.text('4 tools'), findsOneWidget);

      await tester.tap(find.text('Ask simulated agent'));
      await tester.pumpAndSettle();

      expect(store.tasks, hasLength(1));
      expect(store.tasks.single.title, contains('Pick up my package'));

      await tester.scrollUntilVisible(
        find.text('AppFunction result'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('AppFunction result'), findsOneWidget);
      expect(find.textContaining('Pick up my package'), findsWidgets);
    } finally {
      FlutterAppFunctions.instance.unregisterAll();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
