import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/exercise_session_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';
import 'package:hlth_app/core/scoring/vo2max_estimation.dart';

/// Computes and persists the aerobic-fitness (VO2 max) estimate.
///
/// The validated engine (`vo2max_estimation.dart`) is the source of truth and
/// is not modified — this service only ADAPTS our data into it: a band workout
/// summary (`exercise_sessions` row) + the user profile become a
/// [Vo2SessionInput], scored by [computeVo2Max] (Åstrand-Ryhming Algorithm A).
/// The per-session estimate is written back onto the session row; the headline
/// fitness number shown to the user is a confidence-weighted **7-day rolling
/// average** persisted as a `ScoreType.fitness` [Score].
///
/// Triggered (a) right after a workout is upserted (`computeForSession`), and
/// (b) on the post-sync tick (`computeForDay`) so band-native sessions synced
/// without going through the workout screen still get scored.
class Vo2MaxService {
  Vo2MaxService({
    required this.exerciseRepo,
    required this.userRepo,
    required this.dailyRepo,
    required this.scoreRepo,
    this.config = const Vo2Config(),
  });

  final ExerciseSessionRepository exerciseRepo;
  final UserRepository userRepo;
  final DailyMetricsRepository dailyRepo;
  final ScoreRepository scoreRepo;
  final Vo2Config config;

  static const _algorithmVersion = 'vo2max-astrand-v1';

  /// Trailing window for the rolling average + on-screen trend.
  static const _trendDays = 28;
  static const _rollingDays = 7;

  /// Estimate VO2 max for one workout and refresh the rolling fitness score.
  /// Returns the engine result (for logging / debug); persists the per-session
  /// value and the daily Score as side effects.
  Future<Vo2Result?> computeForSession({
    required String userId,
    required String sessionId,
    void Function(String msg)? log,
  }) async {
    final session = await exerciseRepo.getById(sessionId);
    if (session == null) return null;

    final profile = await userRepo.getProfile(userId);
    final ageYears = _ageAt(profile?.dateOfBirth, session.startedAt);
    final restingHr = profile?.restingHrBaseline ??
        (await dailyRepo.getForDay(
          userId: userId,
          localDate: session.startedAt.toLocal(),
        ))
            ?.restingHrBpm;

    final input = Vo2SessionInput(
      sportType: session.sportType,
      durationSec: session.durationSec,
      distanceM: session.distanceM,
      calories: session.calories,
      avgSpeedCmS: session.avgSpeedCmS,
      avgHrBpm: session.avgHrBpm,
      ageYears: ageYears,
      sex: profile?.sexAtBirth ?? SexAtBirth.unknown,
      weightKg: profile?.weightKg,
      restingHrBpm: restingHr,
    );

    final result = computeVo2Max(input, cfg: config);
    log?.call('VO2 session $sessionId: ${result.status.name} '
        'vo2=${result.vo2maxMl?.toStringAsFixed(1) ?? "—"} '
        'conf=${result.confidence.toStringAsFixed(2)} ${result.message}');

    if (result.status == Vo2Status.produced) {
      await exerciseRepo.updateVo2(
        sessionId: sessionId,
        vo2maxMl: result.vo2maxMl,
        vo2Confidence: result.confidence,
      );
      await recomputeFitnessScore(userId: userId, asOf: session.startedAt);
    }
    return result;
  }

  /// Post-sync entry point: refresh the rolling fitness score for [localDate].
  /// Idempotent — recomputes from whatever per-session estimates exist.
  Future<Score?> computeForDay({
    required String userId,
    required DateTime localDate,
  }) =>
      recomputeFitnessScore(userId: userId, asOf: localDate);

  /// Recompute the confidence-weighted rolling VO2 average over the trailing
  /// window and persist it as the daily `ScoreType.fitness` Score.
  Future<Score?> recomputeFitnessScore({
    required String userId,
    required DateTime asOf,
  }) async {
    final from = asOf.subtract(const Duration(days: _trendDays));
    final sessions = await exerciseRepo.getInRange(
      userId: userId,
      from: from,
      to: asOf,
    );
    final scored = sessions.where((s) => s.vo2maxMl != null).toList();
    if (scored.isEmpty) return null;

    final samples = scored
        .map((s) => Vo2Sample(
              at: s.startedAt,
              vo2: s.vo2maxMl!,
              confidence: s.vo2Confidence ?? 1.0,
            ))
        .toList();

    // Prefer the 7-day rolling average; if there's been no recent workout,
    // fall back to the full 28-day window so the card still shows a value.
    final rolling = rollingVo2Avg(samples, asOf: asOf, windowDays: _rollingDays) ??
        rollingVo2Avg(samples, asOf: asOf, windowDays: _trendDays);
    if (rolling == null) return null;

    final latest = scored.last; // getInRange is ascending by start time
    final profile = await userRepo.getProfile(userId);
    final ageYears = _ageAt(profile?.dateOfBirth, asOf);

    String? label;
    int? fitnessAge;
    if (ageYears != null) {
      final fit = fitnessRating(
        rolling,
        ageYears,
        profile?.sexAtBirth ?? SexAtBirth.unknown,
      );
      label = fit.rating;
      fitnessAge = fit.fitnessAge;
    }

    final day = DateTime(asOf.year, asOf.month, asOf.day);
    final score = Score(
      id: ScoreRepository.idFor(userId, ScoreType.fitness, day),
      userId: userId,
      scoreType: ScoreType.fitness,
      computedForDate: day,
      score: rolling, // mL/kg/min (not 0–100; display layer labels the unit)
      rawScore: latest.vo2maxMl,
      label: label,
      confidence: latest.vo2Confidence ?? 0.0,
      provisional: scored.length < 3, // thin until a few workouts banked
      components: {
        'rolling_7d': rolling,
        'latest_vo2': latest.vo2maxMl!,
        'sessions_28d': scored.length.toDouble(),
        if (fitnessAge != null) 'fitness_age': fitnessAge.toDouble(),
      },
      computedAt: DateTime.now().toUtc(),
      algorithmVersion: _algorithmVersion,
    );
    await scoreRepo.upsert(score);
    return score;
  }

  /// Whole years between [dob] and [at]; null if [dob] is null.
  int? _ageAt(DateTime? dob, DateTime at) {
    if (dob == null) return null;
    var age = at.year - dob.year;
    final hadBirthday =
        (at.month > dob.month) || (at.month == dob.month && at.day >= dob.day);
    if (!hadBirthday) age -= 1;
    return age;
  }
}

final vo2MaxServiceProvider = Provider<Vo2MaxService>((ref) {
  return Vo2MaxService(
    exerciseRepo: ref.watch(exerciseSessionRepositoryProvider),
    userRepo: ref.watch(userRepositoryProvider),
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
    scoreRepo: ref.watch(scoreRepositoryProvider),
  );
});
