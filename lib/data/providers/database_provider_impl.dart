import '../database/database.dart';
import 'database_provider.dart';

/// Override [databaseProvider] with a real database instance.
///
/// Call this at app startup in main.dart:
/// ```dart
/// RiverpodScope(<override databaseProvider.overrideWithValue(AppDatabase())>, ...)
/// ```
final databaseOverride = databaseProvider.overrideWithValue(AppDatabase());
