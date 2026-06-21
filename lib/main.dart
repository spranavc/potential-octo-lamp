import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/database/database.dart';
import 'data/providers/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://dwlwkpukuetycufjcdkp.supabase.co',
      publishableKey: 'sb_publishable_RpIxDvQCktZAR6fmoaZ4TQ_moTO5sAJ',
    );
  } catch (e) {
    // Supabase not configured — app runs offline
    debugPrint('Supabase init failed: $e');
  }

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
