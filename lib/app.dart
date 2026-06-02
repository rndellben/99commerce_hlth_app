import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/routing/router.dart';
import 'package:hlth_app/ui/theme/app_theme.dart';

class HlthApp extends ConsumerWidget {
  const HlthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'HLTH',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
