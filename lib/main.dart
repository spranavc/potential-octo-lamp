import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/database/database.dart';
import 'data/providers/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    publishableKey: 'YOUR_ANON_KEY',
  );

  AppDatabase? database;

  try {
    database = AppDatabase();
  } catch (_) {
    // Web or unsupported platform — database stubbed
  }

  runApp(
    ProviderScope(
      overrides: [
        if (database != null) databaseProvider.overrideWithValue(database),
      ],
      child: const ClimbApp(),
    ),
  );
}
