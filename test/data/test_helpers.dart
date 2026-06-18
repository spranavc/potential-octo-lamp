import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:climbapp/data/database/database.dart';

Future<AppDatabase> createTestDatabase() async {
  final db = AppDatabase.fromConnection(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  return db;
}
