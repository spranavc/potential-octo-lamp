import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../data/providers/repository_providers.dart';
import '../../../domain/services/session_service.dart';

/// Represents a single climb that has been logged in the active session.
class LoggedClimb {
  const LoggedClimb({
    required this.gradeSystem,
    required this.gradeValue,
    required this.sent,
    required this.attemptNumber,
    required this.problemNumber,
    required this.rpe,
    required this.tagIds,
    this.completionPercent,
    this.notes,
    this.projectIds = const [],
  });

  final String gradeSystem;
  final String gradeValue;
  final bool sent;
  final int attemptNumber;
  final int problemNumber;
  final double? rpe;
  final int? completionPercent;
  final String? notes;
  final List<int> tagIds;
  final List<int> projectIds;
}

/// State of the active logging session.
class ActiveSessionState {
  const ActiveSessionState({
    this.sessionId,
    this.gymId = 0,
    this.wallId,
    this.startedAt,
    this.climbs = const [],
    this.isActive = false,
    this.selectedProjectIds = const [],
    this.currentProblemNumber = 1,
    this.currentAttemptNumber = 1,
  });

  final int? sessionId;
  final int gymId;
  final int? wallId;
  final DateTime? startedAt;
  final List<LoggedClimb> climbs;
  final bool isActive;
  final List<int> selectedProjectIds;
  final int currentProblemNumber;
  final int currentAttemptNumber;

  int get sendCount => climbs.where((c) => c.sent).length;
  int get failCount => climbs.where((c) => !c.sent).length;
  int get totalCount => climbs.length;

  int get problemCount {
    final problems = <int>{};
    for (final c in climbs) {
      problems.add(c.problemNumber);
    }
    return problems.length;
  }

  ActiveSessionState copyWith({
    int? sessionId,
    int? gymId,
    int? wallId,
    DateTime? startedAt,
    List<LoggedClimb>? climbs,
    bool? isActive,
    List<int>? selectedProjectIds,
    bool clearProject = false,
    int? currentProblemNumber,
    int? currentAttemptNumber,
  }) {
    return ActiveSessionState(
      sessionId: sessionId ?? this.sessionId,
      gymId: gymId ?? this.gymId,
      wallId: wallId ?? this.wallId,
      startedAt: startedAt ?? this.startedAt,
      climbs: climbs ?? this.climbs,
      isActive: isActive ?? this.isActive,
      selectedProjectIds:
          clearProject ? [] : (selectedProjectIds ?? this.selectedProjectIds),
      currentProblemNumber: currentProblemNumber ?? this.currentProblemNumber,
      currentAttemptNumber: currentAttemptNumber ?? this.currentAttemptNumber,
    );
  }
}

/// Manages the lifecycle of an active climbing session.
class ActiveSessionNotifier extends StateNotifier<ActiveSessionState> {
  ActiveSessionNotifier(this._sessionService, this._userId)
      : super(const ActiveSessionState());

  final SessionService _sessionService;
  final String? _userId;

  Future<void> start({
    required int gymId,
    int? wallId,
  }) async {
    if (state.isActive) return;

    final sessionId = await _sessionService.startSession(
      gymId,
      wallId: wallId,
      userId: _userId,
    );
    state = ActiveSessionState(
      sessionId: sessionId,
      gymId: gymId,
      wallId: wallId,
      startedAt: DateTime.now(),
      isActive: true,
    );
  }

  /// Logs a single attempt and persists it immediately.
  Future<void> logAttempt({
    required String gradeSystem,
    required String gradeValue,
    required bool sent,
    double? rpe,
    int? completionPercent,
    String? notes,
    List<int>? tagIds,
  }) async {
    if (!state.isActive || state.sessionId == null) return;

    final projectIds = state.selectedProjectIds.isEmpty ? null : state.selectedProjectIds;

    await _sessionService.logClimb(
      sessionId: state.sessionId!,
      gradeSystem: gradeSystem,
      gradeValue: gradeValue,
      sent: sent,
      attemptNumber: state.currentAttemptNumber,
      problemNumber: state.currentProblemNumber,
      rpe: rpe,
      completionPercent: completionPercent,
      notes: notes,
      tagIds: tagIds,
      projectIds: projectIds,
      userId: _userId,
    );

    final climb = LoggedClimb(
      gradeSystem: gradeSystem,
      gradeValue: gradeValue,
      sent: sent,
      attemptNumber: state.currentAttemptNumber,
      problemNumber: state.currentProblemNumber,
      rpe: rpe,
      completionPercent: completionPercent,
      notes: notes,
      tagIds: tagIds ?? [],
      projectIds: projectIds ?? [],
    );

    state = state.copyWith(
      climbs: [...state.climbs, climb],
    );
  }

  /// Advance to the next attempt on the same problem.
  void nextAttempt() {
    state = state.copyWith(
      currentAttemptNumber: state.currentAttemptNumber + 1,
    );
  }

  /// Move to the next problem (resets attempts, increments problem).
  void nextProblem() {
    state = state.copyWith(
      currentProblemNumber: state.currentProblemNumber + 1,
      currentAttemptNumber: 1,
    );
  }

  /// Resume the same problem (after a send, user wants to keep trying).
  void resumeProblem() {
    state = state.copyWith(
      currentAttemptNumber: state.currentAttemptNumber + 1,
    );
  }

  void toggleProject(int projectId) {
    final current = List<int>.from(state.selectedProjectIds);
    if (current.contains(projectId)) {
      current.remove(projectId);
    } else {
      current.add(projectId);
    }
    state = state.copyWith(selectedProjectIds: current);
  }

  void clearProjects() {
    state = state.copyWith(clearProject: true);
  }

  void setProjects(List<int> projectIds) {
    state = state.copyWith(selectedProjectIds: projectIds);
  }

  Future<void> end() async {
    if (!state.isActive) return;

    await _sessionService.endSession(state.sessionId!);

    state = const ActiveSessionState();
  }

  Future<void> cancel() async {
    final sessionId = state.sessionId;
    if (sessionId != null) {
      await _sessionService.deleteSession(sessionId);
    }
    state = const ActiveSessionState();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService(
    ref.watch(sessionRepositoryProvider),
    ref.watch(climbRepositoryProvider),
  );
});

final activeSessionProvider =
    StateNotifierProvider<ActiveSessionNotifier, ActiveSessionState>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  return ActiveSessionNotifier(
    ref.watch(sessionServiceProvider),
    userId,
  );
});

/// Whether a session is currently being logged.
final isLoggingProvider = Provider<bool>((ref) {
  return ref.watch(activeSessionProvider).isActive;
});
