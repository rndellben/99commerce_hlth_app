import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(bleConnectionStateProvider).maybeWhen(
          data: (s) => s == BleConnectionState.connected,
          orElse: () => false,
        );
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          // Profile section
          _SectionHeader(title: 'Profile'),
          _SettingsTile(
            icon: Icons.person,
            title: 'Personal Info',
            subtitle: 'DOB, sex, height, weight',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.monitor_heart,
            title: 'BP Calibration',
            subtitle: 'Enter cuff reading for accuracy',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.calendar_month,
            title: 'Cycle Tracking',
            subtitle: 'Set up menstrual cycle tracking',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          // Device section
          _SectionHeader(title: 'Device'),
          _SettingsTile(
            icon: connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            title: 'HLTH Band',
            subtitle: connected ? 'Connected' : 'Not connected — tap to manage',
            trailing: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: connected ? AppColors.success : AppColors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
            onTap: () => context.push('/settings/device'),
          ),
          _SettingsTile(
            icon: Icons.battery_std,
            title: 'Band Battery',
            subtitle: '--%',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          // Notifications section
          _SectionHeader(title: 'Notifications'),
          _SettingsTile(
            icon: Icons.notifications,
            title: 'Health Alerts',
            subtitle: 'Fall, rhythm, breathing alerts',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.insights,
            title: 'Weekly Insights',
            subtitle: 'Summary notifications',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          // About section
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About HLTH',
            subtitle: 'v1.0.0',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.description,
            title: 'Disclaimers',
            subtitle: 'Wellness product information',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}
