import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/user.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';

/// FutureProvider used by the router redirect and profile-aware screens:
/// returns the current user's profile (null if onboarding hasn't been
/// completed).
///
/// Extracted from `onboarding_screen.dart` — the router (core) must not
/// depend on a feature screen for a shared read-model.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getProfile(ActiveSession.defaultUserId);
});
