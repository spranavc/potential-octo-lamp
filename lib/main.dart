import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/database.dart';
import 'data/providers/database_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;

  // Only create the database on native platforms. Web will use an in-memory
  // fallback via the provider override (configured in the session screens).
  try {
    database = AppDatabase();
  } catch (_) {
    // Web or unsupported platform — database will be a no-op stub
  }

  runApp(
    ProviderScope(
      overrides: [
        if (database != null)
          databaseProvider.overrideWithValue(database!),
      ],
      child: const ClimbApp(),
    ),
  );
}
