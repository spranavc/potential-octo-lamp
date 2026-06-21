import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:drift/web.dart';

QueryExecutor createConnectionForPlatform() {
  return DatabaseConnection.delayed(
    Future(() async {
      try {
        final result = await WasmDatabase.open(
          databaseName: 'climbapp',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.dart.js'),
        );
        return result.resolvedExecutor;
      } catch (_) {
        // WASM unavailable — fall back to IndexedDB
        return DatabaseConnection(WebDatabase('climbapp'));
      }
    }),
  );
}
