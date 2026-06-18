import 'package:drift/drift.dart';

import 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_io.dart';

/// Creates the appropriate [QueryExecutor] for the current platform.
QueryExecutor createConnection() => createConnectionForPlatform();
