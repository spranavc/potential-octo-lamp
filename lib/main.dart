import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/database/database.dart';
import 'data/providers/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  try {
    database = AppDatabase();
  } catch (_) {}

  // Schedule Supabase init after the app is already running.
  // On web, this avoids blocking the render with a plugin that may not load.
  Future.microtask(() async {
    try {
      await Supabase.initialize(
        url: 'https://dwlwkpukuetycufjcdkp.supabase.co',
        publishableKey: 'sb_publishable_RpIxDvQCktZAR6fmoaZ4TQ_moTO5sAJ',
      );
    } catch (_) {
      // Supabase not available — app runs offline
    }
  });

  runApp(
    ProviderScope(
      overrides: [
        if (database != null) databaseProvider.overrideWithValue(database),
      ],
      child: const ClimbApp(),
    ),
  );
}
