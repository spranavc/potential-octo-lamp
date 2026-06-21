import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/database.dart';
import 'data/providers/database_provider.dart';
import 'supabase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase on all platforms. The passkeys JS bundle in
  // web/index.html is required by the transitive passkeys_web dependency.
  await initSupabase();

  AppDatabase? database;
  try {
    database = AppDatabase();
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        if (database != null) databaseProvider.overrideWithValue(database),
      ],
      child: const ClimbApp(),
    ),
  );
}
