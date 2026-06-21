import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  setUp(() async {
    if (!_supabaseInitialized) {
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'http://localhost:54321',
        publishableKey: 'test-anon-key',
      );
      _supabaseInitialized = true;
    }
  });

  testWidgets('Login screen shows when not authenticated',
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

    // Without a Supabase session, the router redirects to /login.
    expect(find.text('Login'), findsWidgets);
    expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
  });

  testWidgets('Signup screen navigation from login', (WidgetTester tester) async {
    final db = _createTestDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ClimbApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the sign-up link on the login screen
    await tester.tap(find.text("Don't have an account? Sign Up"));
    await tester.pumpAndSettle();

    // Should now be on the sign-up screen
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Already have an account? Login'), findsOneWidget);
  });
}
