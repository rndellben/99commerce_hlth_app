import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/services/supabase_connection_monitor.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Small dot badge showing Supabase connection health (green/amber/red).
class ConnectionIndicator extends ConsumerWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(connectionHealthProvider);
    final (color, tooltip) = switch (health) {
      ConnectionHealth.connected => (AppColors.success, 'Cloud connected'),
      ConnectionHealth.offline => (AppColors.warning, 'Offline'),
      ConnectionHealth.authExpired => (AppColors.error, 'Sign in required'),
    };

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
