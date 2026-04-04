import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelmate_app/features/search/provider/search_provider.dart';
import 'package:travelmate_app/features/search/screens/search_screen.dart';

void main() {
  Widget buildSearchScreen() {
    return MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => SearchProvider(),
        child: const SearchScreen(),
      ),
    );
  }

  testWidgets('SearchScreen renders core UI', (WidgetTester tester) async {
    await tester.pumpWidget(buildSearchScreen());
    await tester.pump();

    expect(find.text('Khám phá'), findsOneWidget);
    expect(
      find.text('Bạn muốn đi đâu? (Đà Nẵng, Phú Quốc...)'),
      findsOneWidget,
    );
    expect(find.text('Nhà hàng'), findsOneWidget);
    expect(find.text('Khách sạn'), findsOneWidget);
    expect(find.text('Tham quan'), findsOneWidget);
  });

  testWidgets('SearchScreen supports typing and clear action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSearchScreen());
    await tester.pump();

    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    await tester.enterText(textFieldFinder, 'Đà Nẵng');
    await tester.pump();

    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.cancel_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.cancel_rounded), findsNothing);
  });
}
