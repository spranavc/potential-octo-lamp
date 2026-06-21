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
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ClimbApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Bottom nav should render
    expect(find.byType(NavigationBar), findsOneWidget);
    // Initial tab is Gyms
    expect(find.text('Gyms'), findsWidgets);
  });

  testWidgets('Login screen can be navigated to', (WidgetTester tester) async {
    final db = _createTestDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ClimbApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Export Data'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });
}
