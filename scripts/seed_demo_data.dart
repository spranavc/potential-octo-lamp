/// Seeds backdated demo climbing data for the dev Playwright account.
///
/// Usage:
///   dart run scripts/seed_demo_data.dart
///
/// Requires SUPABASE_SERVICE_KEY and BDR_TEST_EMAIL env vars.
/// Add to ~/.bashrc:
///   export SUPABASE_SERVICE_KEY="eyJ..."
///
/// The script inserts 5 sessions over ~15 days with varied grades, sends, and
/// tags.  Analytics will populate with this data after the app pulls from Supabase.

import 'dart:io';
import 'dart:math';

import 'package:supabase/supabase.dart';

Future<void> main() async {
  final url = 'https://dwlwkpukuetycufjcdkp.supabase.co';
  final key = Platform.environment['SUPABASE_SERVICE_KEY'] ?? '';
  final email = Platform.environment['BDR_TEST_EMAIL'] ?? '';

  if (key.isEmpty || email.isEmpty) {
    print('ERROR: Set SUPABASE_SERVICE_KEY and BDR_TEST_EMAIL env vars.');
    print('  Add to ~/.bashrc:');
    print('  export SUPABASE_SERVICE_KEY="eyJ..."');
    print('  export BDR_TEST_EMAIL="pranavsc3@gmail.com"');
    return;
  }

  final client = SupabaseClient(url, key);
  final rng = Random();

  // Get the user's UUID from Supabase Auth
  final userId = await _getUserId(client, email);
  if (userId == null) {
    print('ERROR: User $email not found in Supabase Auth.');
    print('  Make sure the dev account exists (sign up in the app first).');
    return;
  }
  print('User ID: $userId');

  // Create a demo gym
  final gymId = await _insertGym(client, userId);
  print('Demo gym created (id: $gymId)');

  // Ensure tags exist
  final tagIds = await _ensureTags(client);

  // Create 5 backdated sessions
  final grades = ['V-Intro', 'V0', 'V1', 'V2', 'V3', 'V4', 'V5'];
  final tagSets = [
    [tagIds['crimpy']!], [tagIds['dynamic']!], [tagIds['slopey']!],
    [tagIds['overhang']!], [tagIds['slab']!],
    [tagIds['crimpy']!, tagIds['overhang']!],
    [tagIds['dynamic']!, tagIds['slopey']!], [],
  ];
  final now = DateTime.now();
  var totalClimbs = 0;

  for (var s = 0; s < 5; s++) {
    final sessionDate = now.subtract(Duration(days: (5 - s) * 3 + rng.nextInt(2)));
    final session = await client.from('sessions').insert({
      'user_id': userId,
      'gym_id': gymId,
      'started_at': sessionDate.toIso8601String(),
      'ended_at': sessionDate.add(const Duration(hours: 1, minutes: 30)).toIso8601String(),
      'sync_status': 'synced',
      'created_at': sessionDate.toIso8601String(),
      'updated_at': sessionDate.toIso8601String(),
    }).select().single();
    final sessionId = session['id'];

    final climbCount = 2 + rng.nextInt(3);
    for (var c = 0; c < climbCount; c++) {
      final grade = grades[rng.nextInt(grades.length)];
      final tagSet = tagSets[rng.nextInt(tagSets.length)];
      final sent = rng.nextDouble() > 0.35;
      final attempts = 1 + rng.nextInt(4);
      final rpe = 3 + rng.nextInt(7);
      final logTime = sessionDate.add(Duration(minutes: c * 15 + rng.nextInt(10)));

      final climb = await client.from('climbs').insert({
        'user_id': userId,
        'session_id': sessionId,
        'grade_system': 'V-scale',
        'grade_value': grade,
        'sent': sent,
        'attempt_number': attempts,
        'problem_number': c + 1,
        'rpe': rpe.toDouble(),
        'logged_at': logTime.toIso8601String(),
        'sync_status': 'synced',
        'created_at': logTime.toIso8601String(),
        'updated_at': logTime.toIso8601String(),
      }).select().single();
      totalClimbs++;

      // Attach tags
      for (final tid in tagSet) {
        await client.from('climb_tags').insert({
          'climb_id': climb['id'],
          'tag_id': tid,
        });
      }
    }

    final dateStr =
        '${sessionDate.month}/${sessionDate.day}/${sessionDate.year}';
    print(
        'Session $dateStr: $climbCount climbs (${'${sessionId}'})');
  }

  print('');
  print('Done! $totalClimbs climbs across 5 sessions seeded for $email.');
  print('Open the app (or re-pull from Supabase) to see analytics.');
}

/// Looks up the Supabase Auth user ID for [email].
Future<String?> _getUserId(SupabaseClient client, String email) async {
  try {
    // Use the admin API to list users and find by email
    final response = await client.auth.admin.listUsers();
    for (final user in response) {
      if (user.email == email) return user.id;
    }
  } catch (e) {
    print('Warning: Could not look up users via admin API ($e)');
  }
  return null;
}

/// Creates a demo gym for [userId] if one doesn't exist.
Future<int> _insertGym(SupabaseClient client, String userId) async {
  // Reuse existing demo gym if present
  final existing = await client
      .from('gyms')
      .select('id')
      .eq('user_id', userId)
      .eq('name', 'Demo Gym');
  if (existing.isNotEmpty) return existing[0]['id'] as int;

  // Let Supabase choose the id — do NOT pass an explicit id.
  try {
    final result = await client.from('gyms').insert({
      'user_id': userId,
      'name': 'Demo Gym',
      'sync_status': 'synced',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).select().single();
    return result['id'] as int;
  } catch (e) {
    print('Gym insert failed ($e), trying again without explicit fields...');
    // Minimal insert — let Supabase handle defaults
    final result = await client.from('gyms').insert({
      'user_id': userId,
      'name': 'Demo Gym',
    }).select().single();
    return result['id'] as int;
  }
}

/// Ensures the 5 default tags exist and returns a name→id map.
Future<Map<String, int>> _ensureTags(SupabaseClient client) async {
  final tags = ['crimpy', 'dynamic', 'slopey', 'overhang', 'slab'];
  final result = <String, int>{};

  for (final name in tags) {
    var existing =
        await client.from('tags').select('id').eq('name', name);
    if (existing.isNotEmpty) {
      result[name] = existing[0]['id'] as int;
    } else {
      final inserted =
          await client.from('tags').insert({'name': name}).select().single();
      result[name] = inserted['id'] as int;
    }
  }

  return result;
}
