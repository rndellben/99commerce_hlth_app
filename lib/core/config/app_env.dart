/// Compile-time environment values injected via `--dart-define-from-file`.
///
/// Usage from the command line:
///
///   flutter run --dart-define-from-file=hlth.env.json
///   flutter build apk --dart-define-from-file=hlth.env.json
///
/// `hlth.env.json` is gitignored. `hlth.env.example.json` is the committed
/// template — copy it to `hlth.env.json` and fill in your project's values.
///
/// Why `--dart-define-from-file` over `flutter_dotenv`:
///   * Compile-time constants → tree-shaken, can't be lifted from the
///     asset bundle by a casual reverse-engineer
///   * No runtime async init dance — env is available before `main()` runs
///   * CI/CD passes the same JSON file via `--dart-define-from-file=$ENV`
///
/// The Supabase anon key is *designed* to ship in clients per Supabase's
/// threat model (RLS is the security boundary). Compile-time bundling
/// beats asset extraction but isn't a secret-storage guarantee.
abstract final class AppEnv {
  /// Project URL, e.g. `https://abcdefg.supabase.co`.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Project anon (public) key. Long-lived JWT; safe to ship.
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Build flavor — `dev` (default) / `staging` / `prod`. Used for log
  /// gating, feature flags, and Sentry tags in V1.1+.
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  /// True when running in a real build (not the dev `flutter run` path).
  static bool get isProd => flavor == 'prod';

  /// Throws a [StateError] with a helpful message if Supabase env values
  /// are missing. Called from [main] before `Supabase.initialize` so the
  /// failure mode is obvious instead of an opaque "Invalid URL" deep in
  /// the SDK.
  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY. '
        'Run with --dart-define-from-file=hlth.env.json '
        '(copy hlth.env.example.json and fill in your project keys).',
      );
    }
  }
}
