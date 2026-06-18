import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';

/// List of all sessions, most recent first.
final sessionListProvider = FutureProvider<List<Session>>((ref) async {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getAll();
});
