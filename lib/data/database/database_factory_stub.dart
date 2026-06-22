import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
// ignore_for_file: deprecated_member_use
import 'package:drift/web.dart';

QueryExecutor createConnectionForPlatform() {
  return DatabaseConnection.delayed(
    Future(() async {
      try {
        final result = await WasmDatabase.open(
          databaseName: 'bolder',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.dart.js'),
        );
        return result.resolvedExecutor;
      } catch (_) {
        // WASM unavailable — fall back to IndexedDB
        return DatabaseConnection(WebDatabase('bolder'));
      }
    }),
  );
}
