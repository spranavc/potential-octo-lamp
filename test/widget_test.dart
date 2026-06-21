import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

bool _supabaseInitialized = false;

void main() {
  setUpAll(() async {
    if (!_supabaseInitialized) {
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'http://localhost:54321',
        publishableKey: 'test-anon-key',
      );
      _supabaseInitialized = true;
    }
  });

  testWidgets('Redirects to login when not authenticated',
      (WidgetTester tester) async {
    final db = _createTestDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ClimbApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Without a session, redirect to /login
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
  });

  testWidgets('Login screen has expected fields', (WidgetTester tester) async {
    final db = _createTestDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ClimbApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
