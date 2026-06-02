import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/routing/router.dart';
import 'package:hlth_app/core/services/sync_service.dart';
import 'package:hlth_app/ui/theme/app_theme.dart';

class HlthApp extends ConsumerWidget {
  const HlthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
