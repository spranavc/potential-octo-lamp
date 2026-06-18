import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:climbapp/app.dart';
import 'package:climbapp/data/database/database.dart';
import 'package:climbapp/data/providers/database_provider.dart';

AppDatabase _createTestDb() {
  return AppDatabase.fromConnection(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

void main() {
  testWidgets('App renders with bottom navigation', (WidgetTester tester) async {
    final db = _createTestDb();
    addTearDown(() => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ClimbApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the app renders and shows the bottom navigation bar
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Navigation between tabs works', (WidgetTester tester) async {
    final db = _createTestDb();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ClimbApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Analytics tab and verify screen loaded
    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Grade Pyramid'), findsOneWidget);

    // Tap Gyms tab and verify screen loaded
    await tester.tap(find.text('Gyms'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to ClimbApp!'), findsOneWidget);

    // Verify Projects is no longer a tab (it's a sub-screen under Session Log)
    expect(find.text('Projects'), findsNothing);

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
