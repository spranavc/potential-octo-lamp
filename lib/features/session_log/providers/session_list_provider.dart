import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';

/// List of all sessions, most recent first.
final sessionListProvider = FutureProvider<List<Session>>((ref) async {
  final repo = ref.watch(sessionRepositoryProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  return repo.getAll(userId: userId);
});
