import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/nightly_record_row.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/nightly_record_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/stress_repository.dart';
import 'package:hlth_app/core/scoring/sleep_epochs_builder.dart';
import 'package:hlth_app/core/scoring/vascular_load.dart' as vl;
import 'package:uuid/uuid.dart';

/// Computes Ryan's Vascular Load (Cardio Load) on the end-of-sleep trigger.
/// Reduces the most recent night to a NightlyRecord, persists it, then runs
/// `computeVascularLoad` over the rolling history and stores a Score.
class CardioLoadService {
  CardioLoadService({
    required this.sleepRepo,
    required this.hrRepo,
    required this.hrvRepo,
    required this.stressRepo,
    required this.nightlyRepo,
    required this.scoreRepo,
  });

  final SleepRepository sleepRepo;
  final HrRepository hrRepo;
  final HrvRepository hrvRepo;
  final StressRepository stressRepo;
  final NightlyRecordRepository nightlyRepo;
  final ScoreRepository scoreRepo;

  static const _uuid = Uuid();
  static const _algorithmVersion = 'vascular-load-engineA-v1';

  /// Returns the engine result when a night was reduced (even if calibrating/
  /// no-score), or null if there was no night session to reduce.
  Future<vl.VascularLoadResult?> computeForLatestNight({
    required String userId,
  }) async {
    // 1. Most recent night session = tonight's trigger.
    final session = await sleepRepo.watchMostRecentNight(userId).first;
    if (session == null) return null;

    final wakeLocal = session.endedAt.toLocal();
    final wakeDate = DateTime(wakeLocal.year, wakeLocal.month, wakeLocal.day);

    // 2. Pull the night's stored samples + stage timeline.
    final epochs = await sleepRepo.getEpochsForSession(session.id);
    final hr = await hrRepo.getInRange(
        userId: userId, from: session.startedAt, to: session.endedAt);
    final hrv = await hrvRepo.getInRange(
        userId: userId, from: session.startedAt, to: session.endedAt);
    final stress = await stressRepo.getInRange(
        userId: userId, from: session.startedAt, to: session.endedAt);

    // 3. Reconstruct per-epoch input → reduce to tonight's NightlyRecord.
    final sleepEpochs = SleepEpochsBuilder.build(
      start: session.startedAt,
      end: session.endedAt,
      stages: epochs,
      hr: hr,
      hrv: hrv,
      stress: stress,
    );
    final dateStr = wakeDate.toIso8601String().substring(0, 10);
    final tonight = vl.reduceSession(dateStr, sleepEpochs);

    // 4. Load history (records BEFORE tonight), compute banked valid count.
    final historyRows = await nightlyRepo.getHistoryBefore(
        userId: userId, beforeDate: wakeDate);
    final history = historyRows.map(_toEngine).toList();
    final banked = history.where((r) => r.valid).length;

    // 5. Run the engine verbatim.
    final result = vl.computeVascularLoad(
      history: history,
      tonight: tonight,
      bankedValidCount: banked,
    );

    // 6. Persist tonight's record AFTER computing (becomes history).
    await nightlyRepo.upsert(NightlyRecordRow(
      id: _uuid.v4(),
      userId: userId,
      localDate: wakeDate,
      hrP5: tonight.hrP5.isFinite ? tonight.hrP5 : null,
      rmssdMedian: tonight.rmssdMedian.isFinite ? tonight.rmssdMedian : null,
      stressMean: tonight.stressMean.isFinite ? tonight.stressMean : null,
      coverage: tonight.coverage,
      valid: tonight.valid,
      computedAt: DateTime.now().toUtc(),
      algorithmVersion: _algorithmVersion,
    ));

    // 7. Persist the Score only when one was produced.
    if (result.produced && result.score != null) {
      await scoreRepo.upsert(Score(
        id: ScoreRepository.idFor(userId, ScoreType.cardioLoad, wakeDate),
        userId: userId,
        scoreType: ScoreType.cardioLoad,
        computedForDate: wakeDate,
        score: result.score!,
        label: result.label,
        provisional: false,
        components: result.components,
        computedAt: DateTime.now().toUtc(),
        algorithmVersion: _algorithmVersion,
      ));
    }
    return result;
  }

  vl.NightlyRecord _toEngine(NightlyRecordRow r) => vl.NightlyRecord(
        date: r.localDate.toIso8601String().substring(0, 10),
        hrP5: r.hrP5 ?? double.nan,
        rmssdMedian: r.rmssdMedian ?? double.nan,
        stressMean: r.stressMean ?? double.nan,
        coverage: r.coverage,
        valid: r.valid,
      );
}

final cardioLoadServiceProvider = Provider<CardioLoadService>((ref) {
  return CardioLoadService(
    sleepRepo: ref.watch(sleepRepositoryProvider),
    hrRepo: ref.watch(hrRepositoryProvider),
    hrvRepo: ref.watch(hrvRepositoryProvider),
    stressRepo: ref.watch(stressRepositoryProvider),
    nightlyRepo: ref.watch(nightlyRecordRepositoryProvider),
    scoreRepo: ref.watch(scoreRepositoryProvider),
  );
});
