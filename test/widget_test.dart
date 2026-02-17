// KitaCare AI — Basic smoke test
// Verifies the app launches and shows the auth screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:kitacare_flutter/main.dart';

void main() {
  testWidgets('App launches and shows KitaCare branding', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const KitaCareApp());

    // Verify the app title appears somewhere on screen
    expect(find.text('KitaCare'), findsWidgets);
  });

  testWidgets('Auth screen shows role selection buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const KitaCareApp());
    await tester.pumpAndSettle();

    // Both role buttons should be visible on the auth screen
    expect(find.text('Individual Donor'), findsOneWidget);
    expect(find.text('Malaysian NGO'),    findsOneWidget);
  });
}