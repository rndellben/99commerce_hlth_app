import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hlth_app/app.dart';
import 'package:hlth_app/core/auth/supabase_client_provider.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    // `main()` calls `Supabase.initialize` BEFORE `runApp`, and
    // `supabaseClientProvider` deliberately reads the already-initialized
    // singleton (see its doc comment) rather than initializing lazily. A
    // widget test has no `main()`, so touching that singleton asserts
    // "You must initialize the supabase instance before calling
    // Supabase.instance" and the whole tree fails to build. Override the
    // provider with a standalone client instead of calling
    // `Supabase.initialize` here — initialize() wants secure-storage and
    // shared-prefs platform channels that don't exist in a headless test.
    //
    // `autoRefreshToken: false` matters: GoTrue otherwise starts a 10s
    // periodic token-refresh timer in its constructor, which outlives the
    // test and trips the `!timersPending` invariant. Nothing here talks to
    // the network — no screen on the boot path issues a query.
    final client = SupabaseClient(
      'https://test.supabase.co',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
        ],
        child: const HlthApp(),
      ),
    );

    // The router's initial location is '/' and auth is not a redirect gate,
    // so this lands on the home screen, whose header renders 'HLTH'.
    expect(find.text('HLTH'), findsWidgets);

    // Building HlthApp wires up the real background machinery on purpose
    // (`ref.watch(periodicSyncCoordinatorProvider)` in its build), which
    // leaves timers pending: the drift database open, ConnectivityService's
    // 3s DNS-lookup timeout, and BandReconnector's 10s post-boot reconnect
    // kick. Unmount first — ProviderScope disposal cancels the periodic
    // ones (BandReconnector's 5-min loop) — then advance the clock past the
    // longest remaining one-shot so the test ends with no pending timers.
    // Without this the test fails on the `!timersPending` invariant even
    // though the assertion above passed.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });
}
