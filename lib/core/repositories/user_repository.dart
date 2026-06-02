import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/user.dart';

/// hlth-repository-api.md §4.1
abstract class UserRepository {
  Future<User> create({
    required String id,
    String? email,
    String? phone,
    String? displayName,
  });

  Future<User?> getById(String userId);
  Future<User?> getByEmail(String email);

  Future<UserProfile?> getProfile(String userId);
  Stream<UserProfile?> watchProfile(String userId);
  Future<void> upsertProfile(UserProfile profile);
}

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._db);
  final db.AppDatabase _db;

  @override
  Future<User> create({
    required String id,
    String? email,
    String? phone,
    String? displayName,
  }) async {
    final now = DateTime.now().toUtc();
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    await _db.into(_db.users).insert(
          db.UsersCompanion.insert(
            id: id,
            email: Value(email),
            phone: Value(phone),
            displayName: Value(displayName),
            createdAtUtc: nowSec,
            updatedAtUtc: nowSec,
          ),
        );
    return User(
      id: id,
      email: email,
      phone: phone,
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<User?> getById(String userId) async {
    final row = await (_db.select(_db.users)..where((t) => t.id.equals(userId)))
        .getSingleOrNull();
    return row == null ? null : _rowToUser(row);
  }

  @override
  Future<User?> getByEmail(String email) async {
    final row = await (_db.select(_db.users)
          ..where((t) => t.email.equals(email)))
        .getSingleOrNull();
    return row == null ? null : _rowToUser(row);
  }

  @override
  Future<UserProfile?> getProfile(String userId) async {
    final row = await (_db.select(_db.userProfiles)
          ..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
    return row == null ? null : _rowToProfile(row);
  }

  @override
  Stream<UserProfile?> watchProfile(String userId) {
    return (_db.select(_db.userProfiles)
          ..where((t) => t.userId.equals(userId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _rowToProfile(row));
  }

  @override
  Future<void> upsertProfile(UserProfile profile) async {
    await _db.into(_db.userProfiles).insertOnConflictUpdate(
          db.UserProfilesCompanion.insert(
            userId: profile.userId,
            dateOfBirth: Value(_dateOnly(profile.dateOfBirth)),
            sexAtBirth: Value(profile.sexAtBirth),
            heightCm: Value(profile.heightCm),
            weightKg: Value(profile.weightKg),
            usesMetric: Value(profile.usesMetric),
            uses24hClock: Value(profile.uses24hClock),
            restingHrBaseline: Value(profile.restingHrBaseline),
            cycleTrackingEnabled: Value(profile.cycleTrackingEnabled),
            lastPeriodStartDate: Value(_dateOnly(profile.lastPeriodStartDate)),
            typicalCycleLength: Value(profile.typicalCycleLength),
            updatedAtUtc: profile.updatedAt.millisecondsSinceEpoch ~/ 1000,
          ),
        );
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  User _rowToUser(db.User r) => User(
        id: r.id,
        email: r.email,
        phone: r.phone,
        displayName: r.displayName,
        createdAt: _utcSecToDt(r.createdAtUtc),
        updatedAt: _utcSecToDt(r.updatedAtUtc),
        deletedAt: r.deletedAtUtc == null ? null : _utcSecToDt(r.deletedAtUtc!),
      );

  UserProfile _rowToProfile(db.UserProfile r) => UserProfile(
        userId: r.userId,
        dateOfBirth: r.dateOfBirth == null ? null : DateTime.parse(r.dateOfBirth!),
        sexAtBirth: r.sexAtBirth,
        heightCm: r.heightCm,
        weightKg: r.weightKg,
        usesMetric: r.usesMetric,
        uses24hClock: r.uses24hClock,
        restingHrBaseline: r.restingHrBaseline,
        cycleTrackingEnabled: r.cycleTrackingEnabled,
        lastPeriodStartDate: r.lastPeriodStartDate == null
            ? null
            : DateTime.parse(r.lastPeriodStartDate!),
        typicalCycleLength: r.typicalCycleLength,
        updatedAt: _utcSecToDt(r.updatedAtUtc),
      );

  String? _dateOnly(DateTime? dt) =>
      dt == null ? null : dt.toIso8601String().substring(0, 10);

  DateTime _utcSecToDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
