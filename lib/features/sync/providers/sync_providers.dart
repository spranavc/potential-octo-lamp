import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/providers/database_provider.dart';
import '../../../domain/services/sync_service.dart';

/// Creates a [SyncService] wired to the local database and Supabase client.
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db, Supabase.instance.client);
});

/// Trigger a full bidirectional sync for the current user.
///
/// Call after app start to pull remote changes and push any local changes that
/// were left pending from a previous session. Safe to call when no user is
/// signed in (no-op).
Future<void> triggerSync(WidgetRef ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  final syncService = ref.read(syncServiceProvider);
  try {
    await syncService.fullSync(userId);
  } catch (_) {
    // Sync failures never block the user — the record stays marked 'pending'
    // and will be retried on the next pushAll.
  }
}

/// Push only (no pull) for the current user's pending rows.
///
/// Lighter-weight than [triggerSync] — use after individual write operations
/// where you don't need to pull remote changes immediately.
Future<void> triggerPushSync(WidgetRef ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  final syncService = ref.read(syncServiceProvider);
  try {
    await syncService.pushAll(userId);
  } catch (_) {
    // Sync failures never block the user.
  }
}
