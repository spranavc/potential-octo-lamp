import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'app.dart';
import 'data/database/database.dart';
import 'data/providers/database_provider.dart';
import 'features/analytics/providers/analytics_providers.dart';
import 'features/gyms/providers/gym_providers.dart';
import 'features/projects/providers/project_providers.dart';
import 'features/session_log/providers/session_list_provider.dart';
import 'features/sync/providers/sync_providers.dart';
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

  final container = ProviderContainer(
    overrides: [
      if (database != null) databaseProvider.overrideWithValue(database),
    ],
  );

  // If the user is signed in, pull remote data and push any pending local
  // changes. Sync failures do not block app launch.
  try {
    if (Supabase.instance.client.auth.currentUser?.id != null) {
      await container.read(syncServiceProvider).fullSync(
            Supabase.instance.client.auth.currentUser!.id,
          );
      // Refresh all providers so the pulled data appears in the UI
      container.invalidate(sessionListProvider);
      container.invalidate(gymListProvider);
      container.invalidate(projectListProvider);
      container.invalidate(allClimbsProvider);
    }
  } catch (_) {}

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const Bolder(),
    ),
  );
}
