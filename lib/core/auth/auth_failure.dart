/// Domain-level auth failure surface. The UI maps these into user-facing
/// messages so widget code never has to know what `AuthException.message`
/// or `AuthApiException.statusCode` look like.
sealed class AuthFailure implements Exception {
  const AuthFailure(this.userMessage);

  /// Short, human-readable explanation safe to show in a SnackBar/banner.
  final String userMessage;

  @override
  String toString() => 'AuthFailure($runtimeType): $userMessage';
}

/// Wrong email + password combo. Don't leak which one is wrong.
class InvalidCredentials extends AuthFailure {
  const InvalidCredentials() : super('Email or password is incorrect.');
}

/// Connection or DNS error before Supabase could respond.
class AuthNetworkError extends AuthFailure {
  const AuthNetworkError()
      : super('No internet connection. Check your network and try again.');
}

/// Password didn't meet the project's complexity requirements.
class WeakPassword extends AuthFailure {
  const WeakPassword() : super('Password must be at least 8 characters.');
}

/// Sign-up failed because someone already registered with this email.
class EmailTaken extends AuthFailure {
  const EmailTaken()
      : super('That email is already registered. Try signing in instead.');
}

/// Email confirmation is on and the user hasn't clicked the link yet.
class EmailNotConfirmed extends AuthFailure {
  const EmailNotConfirmed()
      : super('Please confirm your email via the link we sent.');
}

/// Catch-all for anything we don't recognize. Stashes the original
/// message for log/debug surfaces.
class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure(String original)
      : detail = original,
        super('Something went wrong. Please try again.');

  /// Raw error string from the underlying SDK — log this, don't show it.
  final String detail;
}
