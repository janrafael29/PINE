// Widget tests for FaqScreen (no Firebase required).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pine/screens/faq_screen.dart';

void main() {
  testWidgets('FaqScreen shows title and first question', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FaqScreen(),
      ),
    );

    expect(find.text('FAQ – Frequently Asked Questions'), findsOneWidget);
    expect(find.text('How do I create an account?'), findsOneWidget);
  });
}
