import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/database/database.dart';

import '../../../data/providers/database_provider.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../features/analytics/providers/analytics_providers.dart';
import '../../../features/gyms/providers/gym_providers.dart';
import '../../../features/projects/providers/project_providers.dart';
import '../../../features/session_log/providers/session_list_provider.dart';
import '../../../features/sync/providers/sync_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _exportData(WidgetRef ref, BuildContext context) async {
    final db = ref.read(databaseProvider);
    final sessions = await db.sessionsDao.getAll();
    final climbs = await db.climbsDao.getAll();

    final buffer = StringBuffer();
    buffer.writeln('[');
    for (var i = 0; i < sessions.length; i++) {
      final s = sessions[i];
      final sessionClimbs = await db.climbsDao.getBySessionId(s.id);
      buffer.writeln('  {');
      buffer.writeln('    "id": ${s.id},');
      buffer.writeln('    "gymId": ${s.gymId},');
      buffer.writeln('    "startedAt": "${s.startedAt.toIso8601String()}",');
      if (s.endedAt != null) {
        buffer.writeln('    "endedAt": "${s.endedAt!.toIso8601String()}",');
      }
      buffer.writeln('    "climbs": [');
      for (var j = 0; j < sessionClimbs.length; j++) {
        final c = sessionClimbs[j];
        final tags = await db.climbsDao.getTagsForClimb(c.id);
        final tagNames = tags.map((t) => '"${t.name}"').join(', ');
        buffer.writeln('      {');
        buffer.writeln('        "gradeSystem": "${c.gradeSystem}",');
        buffer.writeln('        "gradeValue": "${c.gradeValue}",');
        buffer.writeln('        "sent": ${c.sent},');
        buffer.writeln('        "attemptNumber": ${c.attemptNumber},');
        buffer.writeln('        "problemNumber": ${c.problemNumber},');
        if (c.rpe != null) buffer.writeln('        "rpe": ${c.rpe},');
        buffer.writeln('        "loggedAt": "${c.loggedAt.toIso8601String()}",');
        buffer.writeln('        "tags": [$tagNames]');
        buffer.writeln('      }${j < sessionClimbs.length - 1 ? ',' : ''}');
      }
      buffer.writeln('    ]');
      buffer.writeln('  }${i < sessions.length - 1 ? ',' : ''}');
    }
    buffer.writeln(']');

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data copied to clipboard')),
      );
    }
  }

  Future<void> _deleteAllData(WidgetRef ref, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync with Boldr'),
        content: const Text(
          'This will replace all local data with the latest data from Boldr servers. '
          'Any unsynced local changes will be pushed first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    // Truncate all user data (respect FK order)
    await db.delete(db.projectClimbs).go();
    await db.delete(db.climbTags).go();
    await db.delete(db.climbs).go();
    await db.delete(db.projects).go();
    await db.delete(db.sessions).go();
    await db.delete(db.gyms).go();

    // Re-seed default tags (they get cascade-deleted)
    for (final tag in ['crimpy', 'dynamic', 'slopey', 'overhang', 'slab']) {
      await db.into(db.tags).insert(
            TagsCompanion.insert(name: tag),
            mode: InsertMode.insertOrIgnore,
          );
    }

    // Pull fresh data from Supabase
    if (userId != null) {
      final syncService = ref.read(syncServiceProvider);
      await syncService.fullSync(userId);
    }

    // Invalidate all providers so UI refreshes
    ref.invalidate(sessionListProvider);
    ref.invalidate(gymListProvider);
    ref.invalidate(myGymsProvider);
    ref.invalidate(projectListProvider);
    ref.invalidate(allClimbsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Synced with Boldr')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Unknown';
    final displayName =
        user?.userMetadata?['display_name'] as String? ?? email;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                email.isNotEmpty ? email[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 32,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              displayName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export Data'),
            subtitle: const Text('Copy your climbing data as JSON'),
            onTap: () => _exportData(ref, context),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync with Boldr'),
            subtitle: const Text('Pull latest data from Boldr servers'),
            onTap: () => _deleteAllData(ref, context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Boldr v1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Boldr',
                applicationVersion: '1.0.0',
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Track your climbs. Get better. Be Boldr.'),
                  ),
                  Text(
                    '© 2026 spranavc. MIT License.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
