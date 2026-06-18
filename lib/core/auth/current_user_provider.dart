import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hlth_app/core/auth/supabase_client_provider.dart';

/// Stream of Supabase auth state changes (`signedIn`, `signedOut`,
/// `tokenRefreshed`, etc.). Single source of truth for "is the user
/// authenticated right now?" across the entire app.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// The currently-authenticated Supabase user, or `null` when signed out.
///
/// Reads the live client.auth.currentUser (Supabase keeps this in sync
/// with the auth-state stream). `authStateProvider` is the trigger for
/// re-evaluation — every state change causes this provider to refresh.
final currentUserProvider = Provider<User?>((ref) {
  // Watching authStateProvider so this rebuilds on every auth event,
  // even though we read the value from client.auth.currentUser (which is
  // mutable and not directly observable).
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

/// The auth UUID string for the active user, or `null` when signed out.
///
/// **This is the provider that replaces `ActiveSession.defaultUserId`**
/// across feature code. Use it like:
///
/// ```dart
/// final uid = ref.watch(currentUserIdProvider);
/// if (uid == null) return const SizedBox.shrink();
/// // ...use uid in your queries
/// ```
///
/// The router redirect guarantees that no health-screen widget is ever
/// built when `currentUserIdProvider` is null, but defensive
/// null-handling at every read site is still required (cleaner than
/// `!`).
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
});
