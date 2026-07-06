import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/exercise_session.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/models/user.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/exercise_session_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';
import 'package:hlth_app/core/scoring/vo2max_estimation.dart';
import 'package:hlth_app/core/services/vo2max_service.dart';

/// Service-level checks for the VO2 max adapter using in-memory fakes (the
/// codebase tests services via injected dependencies, not a real DB). The
/// Algorithm-A math itself is covered in vo2max_estimation_test.dart; here we
/// verify the gates, the per-session write-back, and the rolling fitness Score.
void main() {
  const userId = 'u';

  ExerciseSession session({
    String id = 's1',
    int sportType = 7, // running
    int durationSec = 1800,
    int distanceM = 0,
    double calories = 0,
    int? avgSpeedCmS = 250, // 150 m/min → running
    int? avgHrBpm = 150,
    double? vo2maxMl,
    double? vo2Confidence,
    DateTime? startedAt,
  }) =>
      ExerciseSession(
        id: id,
        userId: userId,
        deviceId: 'd',
        sportType: sportType,
        startedAt: startedAt ?? DateTime.utc(2026, 6, 30, 8),
        durationSec: durationSec,
        distanceM: distanceM,
        calories: calories,
        avgSpeedCmS: avgSpeedCmS,
        avgHrBpm: avgHrBpm,
        vo2maxMl: vo2maxMl,
        vo2Confidence: vo2Confidence,
        source: DataSource.bandScheduled,
        createdAt: DateTime.utc(2026, 6, 30, 9),
      );

  Vo2MaxService build({
    required List<ExerciseSession> sessions,
    UserProfile? profile,
    int? dailyRestingHr,
  }) {
    return Vo2MaxService(
      exerciseRepo: _FakeExerciseRepo(sessions),
      userRepo: _FakeUserRepo(profile),
      dailyRepo: _FakeDailyRepo(dailyRestingHr),
      scoreRepo: _FakeScoreRepo(),
    );
  }

  UserProfile profile({
    bool noDob = false,
    SexAtBirth sex = SexAtBirth.male,
    int? restingHr = 60,
    double? weightKg,
  }) =>
      UserProfile(
        userId: userId,
        // Age 30 on 2026-06-30.
        dateOfBirth: noDob ? null : DateTime.utc(1996, 6, 30),
        sexAtBirth: sex,
        restingHrBaseline: restingHr,
        weightKg: weightKg,
        updatedAt: DateTime.utc(2026, 6, 30),
      );

  test('produced: writes per-session VO2 and persists fitness Score', () async {
    final repo = _FakeExerciseRepo([session()]);
    final scores = _FakeScoreRepo();
    final svc = Vo2MaxService(
      exerciseRepo: repo,
      userRepo: _FakeUserRepo(profile()),
      dailyRepo: _FakeDailyRepo(null),
      scoreRepo: scores,
    );

    final r = await svc.computeForSession(userId: userId, sessionId: 's1');
    expect(r?.status, Vo2Status.produced);

    // Per-session write-back.
    expect(repo.byId('s1')?.vo2maxMl, isNotNull);
    expect(repo.byId('s1')!.vo2maxMl, closeTo(42.1, 0.5));

    // Daily fitness Score persisted with the rolling average.
    final fitness = scores.last;
    expect(fitness, isNotNull);
    expect(fitness!.scoreType, ScoreType.fitness);
    expect(fitness.score, closeTo(42.1, 0.5));
    // Age 30 male median ≈ 46.1 → ratio ≈ 0.91 → Fair.
    expect(fitness.label, 'Fair');
    expect(fitness.components?['sessions_28d'], 1.0);
  });

  test('gate: short session is not scored, no Score persisted', () async {
    final repo = _FakeExerciseRepo([session(durationSec: 300)]);
    final scores = _FakeScoreRepo();
    final svc = Vo2MaxService(
      exerciseRepo: repo,
      userRepo: _FakeUserRepo(profile()),
      dailyRepo: _FakeDailyRepo(null),
      scoreRepo: scores,
    );

    final r = await svc.computeForSession(userId: userId, sessionId: 's1');
    expect(r?.status, Vo2Status.insufficientData);
    expect(repo.byId('s1')?.vo2maxMl, isNull);
    expect(scores.last, isNull);
  });

  test('gate: missing age → missingProfile, nothing written', () async {
    final repo = _FakeExerciseRepo([session()]);
    final scores = _FakeScoreRepo();
    final svc = Vo2MaxService(
      exerciseRepo: repo,
      userRepo: _FakeUserRepo(profile(noDob: true)),
      dailyRepo: _FakeDailyRepo(null),
      scoreRepo: scores,
    );

    final r = await svc.computeForSession(userId: userId, sessionId: 's1');
    expect(r?.status, Vo2Status.missingProfile);
    expect(repo.byId('s1')?.vo2maxMl, isNull);
    expect(scores.last, isNull);
  });

  test('resting HR falls back to daily_metrics when no baseline', () async {
    final repo = _FakeExerciseRepo([session()]);
    final svc = Vo2MaxService(
      exerciseRepo: repo,
      userRepo: _FakeUserRepo(profile(restingHr: null)),
      dailyRepo: _FakeDailyRepo(60),
      scoreRepo: _FakeScoreRepo(),
    );
    final r = await svc.computeForSession(userId: userId, sessionId: 's1');
    expect(r?.status, Vo2Status.produced);
  });

  test('rolling Score averages multiple recent sessions, idempotent', () async {
    final repo = _FakeExerciseRepo([
      session(id: 'a', vo2maxMl: 40, vo2Confidence: 1, startedAt: DateTime.utc(2026, 6, 28)),
      session(id: 'b', vo2maxMl: 50, vo2Confidence: 1, startedAt: DateTime.utc(2026, 6, 29)),
    ]);
    final scores = _FakeScoreRepo();
    final svc = Vo2MaxService(
      exerciseRepo: repo,
      userRepo: _FakeUserRepo(profile()),
      dailyRepo: _FakeDailyRepo(null),
      scoreRepo: scores,
    );

    final s1 = await svc.computeForDay(
        userId: userId, localDate: DateTime.utc(2026, 6, 30));
    expect(s1?.score, 45.0); // (40+50)/2
    expect(s1?.rawScore, 50.0); // latest session

    // Recompute is idempotent — same id, same value.
    final s2 = await svc.computeForDay(
        userId: userId, localDate: DateTime.utc(2026, 6, 30));
    expect(s2?.id, s1?.id);
    expect(s2?.score, 45.0);
    expect(scores.upsertCount, 2);
    expect(scores.distinctIds.length, 1);
  });

  test('no scored sessions → no fitness Score', () async {
    final svc = build(sessions: [session()], profile: profile());
    final r = await svc.computeForDay(
        userId: userId, localDate: DateTime.utc(2026, 6, 30));
    expect(r, isNull);
  });
}

// ── fakes ────────────────────────────────────────────────────────────────
class _FakeExerciseRepo implements ExerciseSessionRepository {
  _FakeExerciseRepo(List<ExerciseSession> seed) {
    for (final s in seed) {
      _byId[s.id] = s;
    }
  }
  final Map<String, ExerciseSession> _byId = {};

  ExerciseSession? byId(String id) => _byId[id];

  @override
  Future<ExerciseSession?> getById(String id) async => _byId[id];

  @override
  Future<List<ExerciseSession>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final out = _byId.values
        .where((s) =>
            !s.startedAt.isBefore(from) && !s.startedAt.isAfter(to))
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return out;
  }

  @override
  Future<void> updateVo2({
    required String sessionId,
    required double? vo2maxMl,
    required double? vo2Confidence,
  }) async {
    final s = _byId[sessionId];
    if (s == null) return;
    _byId[sessionId] = ExerciseSession(
      id: s.id,
      userId: s.userId,
      deviceId: s.deviceId,
      sportType: s.sportType,
      startedAt: s.startedAt,
      endedAt: s.endedAt,
      durationSec: s.durationSec,
      distanceM: s.distanceM,
      calories: s.calories,
      avgSpeedCmS: s.avgSpeedCmS,
      maxSpeedCmS: s.maxSpeedCmS,
      avgHrBpm: s.avgHrBpm,
      minHrBpm: s.minHrBpm,
      maxHrBpm: s.maxHrBpm,
      steps: s.steps,
      stepRate: s.stepRate,
      elevationCm: s.elevationCm,
      uphillCm: s.uphillCm,
      downhillCm: s.downhillCm,
      vo2maxMl: vo2maxMl,
      vo2Confidence: vo2Confidence,
      source: s.source,
      createdAt: s.createdAt,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeUserRepo implements UserRepository {
  _FakeUserRepo(this._profile);
  final UserProfile? _profile;
  @override
  Future<UserProfile?> getProfile(String userId) async => _profile;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeDailyRepo implements DailyMetricsRepository {
  _FakeDailyRepo(this._restingHr);
  final int? _restingHr;
  @override
  Future<DailyMetrics?> getForDay({
    required String userId,
    required DateTime localDate,
  }) async {
    if (_restingHr == null) return null;
    return DailyMetrics(
      id: 'dm',
      userId: userId,
      localDate: localDate,
      tzOffsetMin: 0,
      restingHrBpm: _restingHr,
      computedAt: DateTime.utc(2026, 6, 30),
      algorithmVersion: 'test',
      source: DataSource.bandScheduled,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeScoreRepo implements ScoreRepository {
  Score? last;
  int upsertCount = 0;
  final Set<String> distinctIds = {};
  @override
  Future<void> upsert(Score score) async {
    last = score;
    upsertCount++;
    distinctIds.add(score.id);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
