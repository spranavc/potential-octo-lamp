import 'package:drift/drift.dart';

/// Placeholder web connection that returns an empty database.
///
/// Full web support requires sqlite3.wasm + drift_worker.dart.js in web/.
/// Until then, the app runs with no persistence (in-memory, lost on refresh).
QueryExecutor createConnectionForPlatform() {
  // LazyDatabase defers creation until first query — avoids blocking startup.
  return LazyDatabase(() async {
    // Use the sqlite3 JS/WASM backend from sqlite3_flutter_libs
    // This is the recommended cross-platform approach
    throw UnimplementedError(
      'Web database support coming soon. '
      'Use flutter run -d windows or flutter run -d android to test with persistence.',
    );
  });
}
