import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/routing/router.dart';
import 'package:hlth_app/core/services/scheduled_ppg_capture_service.dart';
import 'package:hlth_app/core/services/sync_service.dart';
import 'package:hlth_app/features/home/home_providers.dart';
import 'package:hlth_app/ui/theme/app_theme.dart';

class HlthApp extends ConsumerStatefulWidget {
  const HlthApp({super.key});

  @override
  ConsumerState<HlthApp> createState() => _HlthAppState();
}

class _HlthAppState extends ConsumerState<HlthApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The home/metric providers below capture the wall-clock date (today,
    // last-24h cutoff) ONCE when they're first built and never refresh it.
    // If the app stays alive across a day boundary — e.g. left running
    // overnight — they keep watching the previous day, so today's freshly
    // written daily_metrics (scheduled overnight captures, manual analyses)
    // are invisible. Invalidating them on resume re-evaluates DateTime.now()
    // so "today" is current again whenever the user returns to the app.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(todayDailyMetricsProvider);
      ref.invalidate(hrSparklineProvider);
      ref.invalidate(spo2SparklineProvider);
      ref.invalidate(hrvSparklineProvider);
      ref.invalidate(bpSparklineProvider);
      ref.invalidate(stressSparklineProvider);
      // Respiratory has no band-native source — it needs an active PPG
      // capture. Kick one on resume so simply re-opening the app refreshes
      // the card. Fully self-gated (skips if already captured today / a
      // capture is in flight / not connected / daily attempt cap reached),
      // so this can't double-capture or run when it shouldn't.
      ref
          .read(scheduledPpgCaptureServiceProvider)
          .maybeRunDaily(userId: ActiveSession.defaultUserId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // HLT-11: read the coordinator once so its tick-stream subscription
    // gets wired at app boot. Riverpod providers are lazy — without this
    // touch, the coordinator wouldn't instantiate until something else
    // happened to read it.
    ref.watch(periodicSyncCoordinatorProvider);
    return MaterialApp.router(
      title: 'HLTH',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
