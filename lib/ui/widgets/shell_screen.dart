import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Shell wrapping all primary-tab screens.
///
/// Tabs (per spec): Home · Activity · Insights · Settings.
/// Tapping the current tab while already on it scrolls the tab's content to
/// the top via [HomeScrollNotifier] / [ActivityScrollNotifier].
class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/activity')) return 1;
    if (path.startsWith('/insights')) return 2;
    if (path.startsWith('/settings')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int tapped) {
    final current = _currentIndex(context);
    if (tapped == current) {
      // Already on this tab — broadcast a scroll-to-top request.
      TabScrollNotifier.of(context)?.scrollToTop();
      return;
    }
    switch (tapped) {
      case 0:
        context.go('/');
      case 1:
        context.go('/activity');
      case 2:
        context.go('/insights');
      case 3:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            selectedIcon:
                Icon(Icons.directions_run, color: AppColors.primary),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon:
                Icon(Icons.auto_awesome, color: AppColors.primary),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// InheritedWidget placed by each shell tab so [ShellScreen] can call
/// `scrollToTop()` when the user taps the already-active tab.
class TabScrollNotifier extends InheritedWidget {
  const TabScrollNotifier({
    super.key,
    required this.scrollToTop,
    required super.child,
  });

  final VoidCallback scrollToTop;

  static TabScrollNotifier? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabScrollNotifier>();

  @override
  bool updateShouldNotify(TabScrollNotifier old) =>
      scrollToTop != old.scrollToTop;
}
