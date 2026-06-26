import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hlth_app/core/database/enums.dart';

part 'score.freezed.dart';

/// hlth-db-schema.md §6.3 — a computed daily score (recovery, wellness,
/// cardio load, …). [score] is 0–100 (one decimal); [components] is the
/// per-input breakdown for debug/telemetry; [provisional] is true while the
/// baseline is still maturing (cold-start).
@freezed
class Score with _$Score {
  const factory Score({
    required String id,
    required String userId,
    required ScoreType scoreType,
    required DateTime computedForDate,
    required double score,
    double? rawScore,
    String? label,
    double? confidence,
    @Default(false) bool provisional,
    Map<String, double>? components,
    required DateTime computedAt,
    required String algorithmVersion,
  }) = _Score;
}
