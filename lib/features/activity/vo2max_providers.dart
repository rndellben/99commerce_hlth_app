import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/repositories/exercise_session_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';
import 'package:hlth_app/ui/widgets/trend_chart_card.dart';

/// Latest aerobic-fitness score (ScoreType.fitness) — the headline VO2 max
/// number, rating label, and confidence shown on the card.
final fitnessScoreProvider = StreamProvider<Score?>((ref) {
  final repo = ref.watch(scoreRepositoryProvider);
  return repo.watchLatest(
    userId: ActiveSession.defaultUserId,
    scoreType: ScoreType.fitness,
  );
});

/// Per-workout VO2 estimates over the trailing 4 weeks, as trend points
/// (one dot per qualifying session). Reactive: updates as new workouts sync.
final vo2TrendProvider = StreamProvider<List<TrendPoint>>((ref) {
  final repo = ref.watch(exerciseSessionRepositoryProvider);
  // 60 most-recent sessions comfortably covers a 4-week window of workouts.
  return repo
      .watchForUser(userId: ActiveSession.defaultUserId, limit: 60)
      .map((sessions) {
    final cutoff = DateTime.now().subtract(const Duration(days: 28));
    return sessions
        .where((s) => s.vo2maxMl != null && s.startedAt.isAfter(cutoff))
        .map((s) => TrendPoint(at: s.startedAt.toLocal(), value: s.vo2maxMl!))
        .toList()
      // watchForUser is newest-first; the chart wants oldest→newest.
      ..sort((a, b) => a.at.compareTo(b.at));
  });
});

/// Whether the profile has the inputs VO2 max needs (date of birth). When
/// false the card shows a "complete your profile" prompt instead of a number.
final profileCompleteForVo2Provider = StreamProvider<bool>((ref) {
  final repo = ref.watch(userRepositoryProvider);
  return repo
      .watchProfile(ActiveSession.defaultUserId)
      .map((p) => p?.dateOfBirth != null);
});
