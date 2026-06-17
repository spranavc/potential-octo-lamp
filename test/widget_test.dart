import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:climbapp/app.dart';

void main() {
  testWidgets('App renders with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ClimbApp(),
      ),
    );

    // Verify the app renders and shows the bottom navigation bar
    expect(find.byType(NavigationBar), findsOneWidget);

    // Verify all 5 nav destinations are present
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Gyms'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify the initial screen is Session Log
    expect(find.text('Session Log'), findsOneWidget);
  });

  testWidgets('Navigation between tabs works', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ClimbApp(),
      ),
    );

    // Tap Analytics tab and verify screen loaded
    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Grade Pyramid'), findsOneWidget);

    // Tap Gyms tab and verify screen loaded
    await tester.tap(find.text('Gyms'));
    await tester.pumpAndSettle();
    expect(find.text('No gyms yet'), findsOneWidget);

    // Tap Projects tab and verify screen loaded
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('No projects yet'), findsOneWidget);

    // Tap Settings tab and verify screen loaded
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Export Data'), findsOneWidget);

    // Tap back to Log and verify
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    expect(find.text('No sessions yet'), findsOneWidget);
  });
}
