import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor createConnectionForPlatform() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = p.join(dbFolder.path, 'climbapp.sqlite');

    return NativeDatabase.createInBackground(File(path));
  });
}
