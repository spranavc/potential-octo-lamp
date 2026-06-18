import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/database.dart';
import 'data/providers/database_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;

  try {
    database = AppDatabase();
  } catch (_) {
    // Web or unsupported platform — database stubbed
  }

  runApp(
    ProviderScope(
      overrides: [
        if (database != null)
          databaseProvider.overrideWithValue(database),
      ],
      child: const ClimbApp(),
    ),
  );
}
