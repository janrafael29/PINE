// Widget tests for PrivacyScreen (no Firebase required).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pine/screens/privacy_screen.dart';

void main() {
  testWidgets('PrivacyScreen shows title and policy content', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyScreen(),
      ),
    );

    expect(find.text('Privacy Policy'), findsNWidgets(2));
    expect(find.text('1. Information We Collect'), findsOneWidget);
  });
}
