import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/repository_providers.dart';
import '../../../domain/services/session_service.dart';

/// Represents a single climb that has been logged in the active session.
class LoggedClimb {
  const LoggedClimb({
    required this.gradeSystem,
    required this.gradeValue,
    required this.sent,
    required this.attempts,
    required this.rpe,
    required this.tagIds,
  });

  final String gradeSystem;
  final String gradeValue;
  final bool sent;
  final int attempts;
  final double? rpe;
  final List<int> tagIds;
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
  });

  final int? sessionId;
  final int gymId;
  final int? wallId;
  final DateTime? startedAt;
  final List<LoggedClimb> climbs;
  final bool isActive;

  int get sendCount => climbs.where((c) => c.sent).length;
  int get failCount => climbs.where((c) => !c.sent).length;
  int get totalCount => climbs.length;

  ActiveSessionState copyWith({
    int? sessionId,
    int? gymId,
    int? wallId,
    DateTime? startedAt,
    List<LoggedClimb>? climbs,
    bool? isActive,
  }) {
    return ActiveSessionState(
      sessionId: sessionId ?? this.sessionId,
      gymId: gymId ?? this.gymId,
      wallId: wallId ?? this.wallId,
      startedAt: startedAt ?? this.startedAt,
      climbs: climbs ?? this.climbs,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Manages the lifecycle of an active climbing session.
class ActiveSessionNotifier extends StateNotifier<ActiveSessionState> {
  ActiveSessionNotifier(this._sessionService)
      : super(const ActiveSessionState());

  final SessionService _sessionService;

  Future<void> start({
    required int gymId,
    int? wallId,
  }) async {
    if (state.isActive) return;

    final sessionId = await _sessionService.startSession(gymId, wallId: wallId);
    state = ActiveSessionState(
      sessionId: sessionId,
      gymId: gymId,
      wallId: wallId,
      startedAt: DateTime.now(),
      isActive: true,
    );
  }

  void logClimb({
    required String gradeSystem,
    required String gradeValue,
    required bool sent,
    int attempts = 1,
    double? rpe,
    List<int>? tagIds,
  }) {
    if (!state.isActive) return;

    final climb = LoggedClimb(
      gradeSystem: gradeSystem,
      gradeValue: gradeValue,
      sent: sent,
      attempts: attempts,
      rpe: rpe,
      tagIds: tagIds ?? [],
    );

    state = state.copyWith(
      climbs: [...state.climbs, climb],
    );
  }

  Future<void> end() async {
    if (!state.isActive) return;

    await _sessionService.endSession(state.sessionId!);

    // Persist all logged climbs
    for (final climb in state.climbs) {
      await _sessionService.logClimb(
        sessionId: state.sessionId!,
        gradeSystem: climb.gradeSystem,
        gradeValue: climb.gradeValue,
        sent: climb.sent,
        attempts: climb.attempts,
        rpe: climb.rpe,
        tagIds: climb.tagIds,
      );
    }

    state = const ActiveSessionState();
  }

  void cancel() {
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
  return ActiveSessionNotifier(
    ref.watch(sessionServiceProvider),
  );
});

/// Whether a session is currently being logged.
final isLoggingProvider = Provider<bool>((ref) {
  return ref.watch(activeSessionProvider).isActive;
});
