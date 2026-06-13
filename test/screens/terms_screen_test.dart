// Widget tests for TermsScreen (no Firebase required).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pine/screens/terms_screen.dart';

void main() {
  testWidgets('TermsScreen shows title and terms content', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TermsScreen(),
      ),
    );

    expect(find.text('Terms of Use'), findsNWidgets(2));
    expect(find.text('1. Acceptance of Terms'), findsOneWidget);
  });
}
