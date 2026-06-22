import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/database/database.dart';

/// Handles bidirectional sync between the local Drift database and Supabase.
///
/// Push: local rows with syncStatus != 'synced' are upserted to Supabase.
/// Pull: remote rows are upserted into the local database and marked synced.
///
/// The local auto-increment id is used as the Supabase primary key — Postgres
/// BIGSERIAL accepts explicit integer values, so we push with the local id and
/// pull matching on that same id.
class SyncService {
  const SyncService(this.db, this.supabase);

  final AppDatabase db;
  final SupabaseClient supabase;

  // ---------------------------------------------------------------------------
  // Push
  // ---------------------------------------------------------------------------

  /// Push all pending entities for [userId].
  Future<void> pushAll(String userId) async {
    await pushGyms(userId);
    await pushSessions(userId);
    await pushClimbs(userId);
    await pushProjects(userId);
  }

  Future<void> pushGyms(String userId) async {
    final rows = await (db.select(db.gyms)
          ..where((g) =>
              g.syncStatus.equals('pending') & g.userId.equals(userId)))
        .get();

    if (rows.isEmpty) return;

    final now = DateTime.now();
    final batch = rows.map((g) => {
          'id': g.id,
          'name': g.name,
          'user_id': g.userId,
          'latitude': g.latitude,
          'longitude': g.longitude,
          'created_at': g.createdAt.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).toList();

    try {
      await supabase.from('gyms').upsert(batch);
      await _markSynced(db.gyms, rows.map((g) => g.id).toList(), now);
      debugPrint('[Sync] Pushed ${batch.length} gyms');
    } catch (e) {
      debugPrint('[Sync] pushGyms failed: $e');
    }
  }

  Future<void> pushSessions(String userId) async {
    final rows = await (db.select(db.sessions)
          ..where((s) =>
              s.syncStatus.equals('pending') & s.userId.equals(userId)))
        .get();

    if (rows.isEmpty) return;

    // Ensure all referenced gyms exist in Supabase first
    await _ensureGymsPushed(rows.map((s) => s.gymId).toSet().toList(), userId);

    final now = DateTime.now();
    final batch = rows.map((s) => {
          'id': s.id,
          'gym_id': s.gymId,
          'wall_id': s.wallId,
          'started_at': s.startedAt.toIso8601String(),
          'ended_at': s.endedAt?.toIso8601String(),
          'notes': s.notes,
          'user_id': s.userId,
          'created_at': s.createdAt.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).toList();

    try {
      await supabase.from('sessions').upsert(batch);
      await _markSynced(db.sessions, rows.map((s) => s.id).toList(), now);
      debugPrint('[Sync] Pushed ${batch.length} sessions');
    } catch (e) {
      debugPrint('[Sync] pushSessions failed: $e');
    }
  }

  Future<void> pushClimbs(String userId) async {
    final rows = await (db.select(db.climbs)
          ..where((c) =>
              c.syncStatus.equals('pending') & c.userId.equals(userId)))
        .get();

    if (rows.isEmpty) return;

    // Ensure all referenced sessions exist in Supabase first
    await _ensureSessionsPushed(rows.map((c) => c.sessionId).toSet().toList(), userId);

    final now = DateTime.now();
    final batch = rows.map((c) => {
          'id': c.id,
          'session_id': c.sessionId,
          'grade_system': c.gradeSystem,
          'grade_value': c.gradeValue,
          'sent': c.sent,
          'attempt_number': c.attemptNumber,
          'problem_number': c.problemNumber,
          'rpe': c.rpe,
          'completion_percent': c.completionPercent,
          'notes': c.notes,
          'logged_at': c.loggedAt.toIso8601String(),
          'user_id': c.userId,
          'created_at': c.createdAt.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).toList();

    try {
      await supabase.from('climbs').upsert(batch);
      await _markSynced(db.climbs, rows.map((c) => c.id).toList(), now);
      debugPrint('[Sync] Pushed ${batch.length} climbs');
    } catch (e) {
      debugPrint('[Sync] pushClimbs failed: $e');
    }
  }

  Future<void> pushProjects(String userId) async {
    final rows = await (db.select(db.projects)
          ..where((p) =>
              p.syncStatus.equals('pending') & p.userId.equals(userId)))
        .get();

    if (rows.isEmpty) return;

    // Ensure all referenced gyms exist in Supabase first
    await _ensureGymsPushed(rows.map((p) => p.gymId).toSet().toList(), userId);

    // And referenced climbs too (if any are linked via project_climbs)
    // For now projects are created before climbs are linked, so just ensure gyms.

    final now = DateTime.now();
    final batch = rows.map((p) => {
          'id': p.id,
          'gym_id': p.gymId,
          'name': p.name,
          'grade_system': p.gradeSystem,
          'grade_value': p.gradeValue,
          'description': p.description,
          'status': p.status,
          'started_at': p.startedAt?.toIso8601String(),
          'completed_at': p.completedAt?.toIso8601String(),
          'user_id': p.userId,
          'created_at': p.createdAt.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).toList();

    try {
      await supabase.from('projects').upsert(batch);
      await _markSynced(db.projects, rows.map((p) => p.id).toList(), now);
      debugPrint('[Sync] Pushed ${batch.length} projects');
    } catch (e) {
      debugPrint('[Sync] pushProjects failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Pull
  // ---------------------------------------------------------------------------

  /// Pull all remote entities for [userId].
  Future<void> pullAll(String userId) async {
    await pullGyms(userId);
    await pullSessions(userId);
    await pullClimbs(userId);
    await pullProjects(userId);
  }

  Future<void> pullGyms(String userId) async {
    try {
      final data = await supabase
          .from('gyms')
          .select()
          .eq('user_id', userId) as List<dynamic>;

      debugPrint('[Sync] Pulled ${data.length} gyms from Supabase');

      if (data.isEmpty) return;

      final now = DateTime.now();
      for (final row in data) {
        final map = _asMap(row);
        final id = map['id'] as int;
        final name = map['name'] as String;
        final existing = await (db.select(db.gyms)
              ..where((g) => g.id.equals(id)))
            .getSingleOrNull();

        if (existing != null) {
          await (db.update(db.gyms)..where((g) => g.id.equals(id))).write(
            GymsCompanion(
              name: Value(name),
              userId: Value(map['user_id'] as String?),
              latitude: Value((map['latitude'] as num?)?.toDouble()),
              longitude: Value((map['longitude'] as num?)?.toDouble()),
              syncStatus: const Value('synced'),
              updatedAt: Value(now),
            ),
          );
        } else {
          await db.into(db.gyms).insert(
            GymsCompanion.insert(
              id: Value(id),
              name: name,
              userId: Value(map['user_id'] as String?),
              latitude: Value((map['latitude'] as num?)?.toDouble()),
              longitude: Value((map['longitude'] as num?)?.toDouble()),
              syncStatus: const Value('synced'),
              createdAt: Value(
                DateTime.tryParse(map['created_at']?.toString() ?? '') ?? now,
              ),
              updatedAt: Value(now),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Sync] pullGyms failed: $e');
    }
  }

  Future<void> pullSessions(String userId) async {
    try {
      final data = await supabase
          .from('sessions')
          .select()
          .eq('user_id', userId) as List<dynamic>;

      debugPrint('[Sync] Pulled ${data.length} sessions from Supabase');

      if (data.isEmpty) return;

      final now = DateTime.now();
      for (final row in data) {
        final map = _asMap(row);
        final id = map['id'] as int;
        final existing = await (db.select(db.sessions)
              ..where((s) => s.id.equals(id)))
            .getSingleOrNull();

        if (existing != null) {
          await (db.update(db.sessions)..where((s) => s.id.equals(id))).write(
            SessionsCompanion(
              gymId: Value(map['gym_id'] as int),
              wallId: Value(map['wall_id'] as int?),
              startedAt: Value(DateTime.parse(map['started_at'].toString())),
              endedAt: Value(_tryParse(map['ended_at'])),
              notes: Value(map['notes'] as String?),
              userId: Value(map['user_id'] as String?),
              syncStatus: const Value('synced'),
              updatedAt: Value(now),
            ),
          );
        } else {
          await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: Value(id),
              gymId: map['gym_id'] as int,
              wallId: Value(map['wall_id'] as int?),
              startedAt: DateTime.parse(map['started_at'].toString()),
              endedAt: Value(_tryParse(map['ended_at'])),
              notes: Value(map['notes'] as String?),
              userId: Value(map['user_id'] as String?),
              syncStatus: const Value('synced'),
              createdAt: Value(
                DateTime.tryParse(map['created_at']?.toString() ?? '') ?? now,
              ),
              updatedAt: Value(now),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Sync] pullSessions failed: $e');
    }
  }

  Future<void> pullClimbs(String userId) async {
    try {
      final data = await supabase
          .from('climbs')
          .select()
          .eq('user_id', userId) as List<dynamic>;

      debugPrint('[Sync] Pulled ${data.length} climbs from Supabase');

      if (data.isEmpty) return;

      final now = DateTime.now();
      for (final row in data) {
        final map = _asMap(row);
        final id = map['id'] as int;
        final existing = await (db.select(db.climbs)
              ..where((c) => c.id.equals(id)))
            .getSingleOrNull();

        if (existing != null) {
          await (db.update(db.climbs)..where((c) => c.id.equals(id))).write(
            ClimbsCompanion(
              sessionId: Value(map['session_id'] as int),
              gradeSystem: Value(map['grade_system'] as String),
              gradeValue: Value(map['grade_value'] as String),
              sent: Value((map['sent'] as bool?) ?? false),
              attemptNumber: Value((map['attempt_number'] as int?) ?? 1),
              problemNumber: Value((map['problem_number'] as int?) ?? 1),
              rpe: Value((map['rpe'] as num?)?.toDouble()),
              completionPercent: Value(map['completion_percent'] as int?),
              notes: Value(map['notes'] as String?),
              loggedAt: Value(DateTime.parse(map['logged_at'].toString())),
              userId: Value(map['user_id'] as String?),
              syncStatus: const Value('synced'),
              updatedAt: Value(now),
            ),
          );
        } else {
          await db.into(db.climbs).insert(
            ClimbsCompanion.insert(
              id: Value(id),
              sessionId: map['session_id'] as int,
              gradeSystem: map['grade_system'] as String,
              gradeValue: map['grade_value'] as String,
              sent: (map['sent'] as bool?) ?? false,
              attemptNumber:
                  Value((map['attempt_number'] as int?) ?? 1),
              problemNumber: Value((map['problem_number'] as int?) ?? 1),
              rpe: Value((map['rpe'] as num?)?.toDouble()),
              completionPercent: Value(map['completion_percent'] as int?),
              notes: Value(map['notes'] as String?),
              loggedAt: DateTime.parse(map['logged_at'].toString()),
              userId: Value(map['user_id'] as String?),
              syncStatus: const Value('synced'),
              createdAt: Value(
                DateTime.tryParse(map['created_at']?.toString() ?? '') ?? now,
              ),
              updatedAt: Value(now),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Sync] pullClimbs failed: $e');
    }
  }

  Future<void> pullProjects(String userId) async {
    try {
      final data = await supabase
          .from('projects')
          .select()
          .eq('user_id', userId) as List<dynamic>;

      debugPrint('[Sync] Pulled ${data.length} projects from Supabase');

      if (data.isEmpty) return;

      final now = DateTime.now();
      for (final row in data) {
        final map = _asMap(row);
        final id = map['id'] as int;
        final existing = await (db.select(db.projects)
              ..where((p) => p.id.equals(id)))
            .getSingleOrNull();

        if (existing != null) {
          await (db.update(db.projects)..where((p) => p.id.equals(id))).write(
            ProjectsCompanion(
              gymId: Value(map['gym_id'] as int),
              name: Value(map['name'] as String),
              gradeSystem: Value(map['grade_system'] as String),
              gradeValue: Value(map['grade_value'] as String),
              description: Value(map['description'] as String?),
              status: Value((map['status'] as String?) ?? 'active'),
              startedAt: Value(_tryParse(map['started_at'])),
              completedAt: Value(_tryParse(map['completed_at'])),
              userId: Value(map['user_id'] as String?),
              syncStatus: const Value('synced'),
              updatedAt: Value(now),
            ),
          );
        } else {
          await db.into(db.projects).insert(
            ProjectsCompanion.insert(
              id: Value(id),
              gymId: map['gym_id'] as int,
              name: map['name'] as String,
              gradeSystem: map['grade_system'] as String,
              gradeValue: map['grade_value'] as String,
              description: Value(map['description'] as String?),
              status: Value((map['status'] as String?) ?? 'active'),
              startedAt: Value(_tryParse(map['started_at'])),
              completedAt: Value(_tryParse(map['completed_at'])),
              userId: Value(map['user_id'] as String?),
              syncStatus: const Value('synced'),
              createdAt: Value(
                DateTime.tryParse(map['created_at']?.toString() ?? '') ?? now,
              ),
              updatedAt: Value(now),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Sync] pullProjects failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Full sync
  // ---------------------------------------------------------------------------

  /// Push local changes, then pull remote changes.
  Future<void> fullSync(String userId) async {
    await pushAll(userId);
    await pullAll(userId);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Ensure [gymIds] exist in Supabase. Pushes any missing gyms from local DB.
  Future<void> _ensureGymsPushed(List<int> gymIds, String userId) async {
    if (gymIds.isEmpty) return;
    final rows = await (db.select(db.gyms)
          ..where((g) => g.id.isIn(gymIds) & g.userId.equals(userId)))
        .get();
    if (rows.isEmpty) return;
    final now = DateTime.now();
    final batch = rows.map((g) => {
          'id': g.id,
          'name': g.name,
          'user_id': g.userId,
          'latitude': g.latitude,
          'longitude': g.longitude,
          'created_at': g.createdAt.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).toList();
    try {
      await supabase.from('gyms').upsert(batch);
      debugPrint('[Sync] Ensured ${batch.length} gyms pushed');
    } catch (e) {
      debugPrint('[Sync] _ensureGymsPushed failed: $e');
    }
  }

  /// Ensure [sessionIds] exist in Supabase. Pushes any missing sessions (and
  /// their gyms) from local DB.
  Future<void> _ensureSessionsPushed(List<int> sessionIds, String userId) async {
    if (sessionIds.isEmpty) return;
    // Push any missing gyms first
    final sessionRows = await (db.select(db.sessions)
          ..where((s) => s.id.isIn(sessionIds) & s.userId.equals(userId)))
        .get();
    if (sessionRows.isEmpty) return;
    await _ensureGymsPushed(
        sessionRows.map((s) => s.gymId).toSet().toList(), userId);

    final now = DateTime.now();
    final batch = sessionRows.map((s) => {
          'id': s.id,
          'gym_id': s.gymId,
          'wall_id': s.wallId,
          'started_at': s.startedAt.toIso8601String(),
          'ended_at': s.endedAt?.toIso8601String(),
          'notes': s.notes,
          'user_id': s.userId,
          'created_at': s.createdAt.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).toList();
    try {
      await supabase.from('sessions').upsert(batch);
      debugPrint('[Sync] Ensured ${batch.length} sessions pushed');
    } catch (e) {
      debugPrint('[Sync] _ensureSessionsPushed failed: $e');
    }
  }

  /// Mark rows matching [ids] as 'synced' with the given [updatedAt].
  Future<void> _markSynced<T extends Table, D>(
    TableInfo<T, D> table,
    List<int> ids,
    DateTime now,
  ) async {
    if (ids.isEmpty) return;

    // Build a raw UPDATE since Drift doesn't have a bulk-id update API.
    final placeholders = ids.map((_) => '?').join(', ');
    final statement =
        'UPDATE ${table.actualTableName} SET sync_status = ?, updated_at = ? WHERE id IN ($placeholders)';
    await db.customUpdate(
      statement,
      variables: [
        Variable.withString('synced'),
        Variable.withDateTime(now),
        ...ids.map(Variable.withInt),
      ],
    );
  }

  /// Mark rows matching [ids] as 'pending'.
  Future<void> markPending(
    TableInfo table,
    List<int> ids,
  ) async {
    if (ids.isEmpty) return;

    final placeholders = ids.map((_) => '?').join(', ');
    final statement =
        'UPDATE ${table.actualTableName} SET sync_status = ? WHERE id IN ($placeholders)';
    await db.customUpdate(
      statement,
      variables: [
        Variable.withString('pending'),
        ...ids.map(Variable.withInt),
      ],
    );
  }

  /// Convert a Supabase row to a proper `Map<String, dynamic>`.
  static Map<String, dynamic> _asMap(dynamic row) {
    if (row is Map<String, dynamic>) return row;
    // Supabase may return a custom JSON type, force-cast.
    return Map<String, dynamic>.from(row as Map);
  }

  /// Try to parse a nullable ISO 8601 string into a DateTime.
  static DateTime? _tryParse(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}
