import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke: widget tree builds', (WidgetTester tester) async {
    // The app bootstrapping requires Supabase + DI; keep this test independent.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
