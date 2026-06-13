// Basic Flutter widget test for PINE app.
// Run: flutter test test/widget_test.dart
//
// Full MyApp() requires Supabase env vars; we
// test the initial screen in isolation: TermsAcceptanceScreen is what users see
// first when terms are not yet accepted.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pine/screens/terms_acceptance_screen.dart';

void main() {
  testWidgets('PINE initial screen shows terms welcome', (WidgetTester tester) async {
    // Use a viewport large enough so TermsAcceptanceScreen layout does not overflow (test default can be small).
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: TermsAcceptanceScreen(),
      ),
    );

    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('PINYA-PIC'), findsOneWidget);
    expect(find.text('Pest Identification on Native Environments'), findsOneWidget);
  });
}
