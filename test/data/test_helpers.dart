import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bolder/data/database/database.dart';

bool _supabaseInitialized = false;

Future<void> initWithSupabase() async {
  if (!_supabaseInitialized) {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-anon-key',
    );
    _supabaseInitialized = true;
  }
}

Future<AppDatabase> createTestDatabase() async {
  await initWithSupabase();
  final db = AppDatabase.fromConnection(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  return db;
}
