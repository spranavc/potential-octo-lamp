import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/database.dart';
import 'data/providers/database_provider.dart';
import 'supabase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase only works on native platforms. On web, the import pulls in
  // platform plugins that crash the JS runtime. We skip it entirely on web.
  if (!kIsWeb) {
    await initSupabase();
  }

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
