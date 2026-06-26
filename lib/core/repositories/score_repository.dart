import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/score.dart';

/// hlth-repository-api.md §6.3 — persistence for computed daily scores.
abstract class ScoreRepository {
  /// Deterministic per-(user, type, day) id so daily recompute upserts in place.
  static String idFor(String userId, ScoreType type, DateTime date) =>
      '$userId:${type.index}:${date.toIso8601String().substring(0, 10)}';

  Future<Score?> getById(String id);

  /// Latest score of [scoreType] on or before [forDate].
  Future<Score?> getCurrent({
    required String userId,
    required ScoreType scoreType,
    required DateTime forDate,
  });

  /// Latest score of [scoreType] strictly before [beforeDate] (smoothing input).
  Future<Score?> getPrevious({
    required String userId,
    required ScoreType scoreType,
    required DateTime beforeDate,
  });

  /// Reactive latest score of [scoreType] (for the home card).
  Stream<Score?> watchLatest({
    required String userId,
    required ScoreType scoreType,
  });

  Future<List<Score>> getHistory({
    required String userId,
    required ScoreType scoreType,
    int? limit,
  });

  Future<void> upsert(Score score);
}

class ScoreRepositoryImpl implements ScoreRepository {
  ScoreRepositoryImpl(this._db);
  final db.AppDatabase _db;

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
  String _dateOnly(DateTime dt) => dt.toIso8601String().substring(0, 10);

  Score _rowToDomain(db.Score r) => Score(
        id: r.id,
        userId: r.userId,
        scoreType: r.scoreType,
        computedForDate: DateTime.parse(r.computedForDate),
        score: r.score,
        rawScore: r.rawScore,
        label: r.label,
        confidence: r.confidence,
        provisional: r.provisional,
        components: r.components == null
            ? null
            : (jsonDecode(r.components!) as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, (v as num).toDouble())),
        computedAt: _toDt(r.computedAtUtc),
        algorithmVersion: r.algorithmVersion,
      );

  db.ScoresCompanion _toCompanion(Score s) => db.ScoresCompanion.insert(
        id: s.id,
        userId: s.userId,
        scoreType: s.scoreType,
        computedForDate: _dateOnly(s.computedForDate),
        score: s.score,
        rawScore: Value(s.rawScore),
        label: Value(s.label),
        confidence: Value(s.confidence),
        provisional: Value(s.provisional),
        components:
            Value(s.components == null ? null : jsonEncode(s.components)),
        computedAtUtc: _toSec(s.computedAt),
        algorithmVersion: s.algorithmVersion,
      );

  @override
  Future<Score?> getById(String id) async {
    final row = await (_db.select(_db.scores)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Future<Score?> getCurrent({
    required String userId,
    required ScoreType scoreType,
    required DateTime forDate,
  }) async {
    final row = await (_db.select(_db.scores)
          ..where((t) =>
              t.userId.equals(userId) &
              t.scoreType.equals(scoreType.index) &
              t.computedForDate.isSmallerOrEqualValue(_dateOnly(forDate)))
          ..orderBy([(t) => OrderingTerm.desc(t.computedForDate)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Future<Score?> getPrevious({
    required String userId,
    required ScoreType scoreType,
    required DateTime beforeDate,
  }) async {
    final row = await (_db.select(_db.scores)
          ..where((t) =>
              t.userId.equals(userId) &
              t.scoreType.equals(scoreType.index) &
              t.computedForDate.isSmallerThanValue(_dateOnly(beforeDate)))
          ..orderBy([(t) => OrderingTerm.desc(t.computedForDate)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Stream<Score?> watchLatest({
    required String userId,
    required ScoreType scoreType,
  }) {
    return (_db.select(_db.scores)
          ..where((t) =>
              t.userId.equals(userId) & t.scoreType.equals(scoreType.index))
          ..orderBy([(t) => OrderingTerm.desc(t.computedForDate)])
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _rowToDomain(row));
  }

  @override
  Future<List<Score>> getHistory({
    required String userId,
    required ScoreType scoreType,
    int? limit,
  }) async {
    final q = _db.select(_db.scores)
      ..where((t) =>
          t.userId.equals(userId) & t.scoreType.equals(scoreType.index))
      ..orderBy([(t) => OrderingTerm.desc(t.computedForDate)]);
    if (limit != null) q.limit(limit);
    final rows = await q.get();
    return rows.map(_rowToDomain).toList();
  }

  @override
  Future<void> upsert(Score score) async {
    await _db.into(_db.scores).insertOnConflictUpdate(_toCompanion(score));
  }
}

final scoreRepositoryProvider = Provider<ScoreRepository>((ref) {
  return ScoreRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
