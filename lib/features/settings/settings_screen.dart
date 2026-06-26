import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hlth_app/core/auth/current_user_provider.dart';
import 'package:hlth_app/core/auth/supabase_client_provider.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/user.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';
import 'package:hlth_app/features/onboarding/onboarding_screen.dart';
import 'package:hlth_app/features/settings/monitoring_screen.dart';
import 'package:hlth_app/features/settings/notifications_screen.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(bleConnectionStateProvider).maybeWhen(
          data: (s) => s == BleConnectionState.connected,
          orElse: () => false,
        );
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),

          // ── User Profile ────────────────────────────────────────────
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'User Profile',
            subtitle: profile != null
                ? '${profile.heightCm?.round() ?? '--'} cm · ${profile.weightKg?.round() ?? '--'} kg'
                : 'Set up your profile',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const _ProfileViewScreen()),
            ),
          ),

          // ── AI Insights (Coming Soon) ──────────────────────────────
          _SettingsTile(
            icon: Icons.auto_awesome_outlined,
            title: 'AI Insights',
            subtitle: 'Coming soon',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const _ComingSoonScreen(
                  title: 'AI Insights',
                  description:
                      'Personalized health insights powered by AI will be available in a future update.',
                  icon: Icons.auto_awesome_outlined,
                ),
              ),
            ),
          ),

          // ── HLTH Plugs (Coming Soon) ───────────────────────────────
          _SettingsTile(
            icon: Icons.extension_outlined,
            title: 'HLTH Plugs',
            subtitle: 'Coming soon',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const _ComingSoonScreen(
                  title: 'HLTH Plugs',
                  description:
                      'Connect third-party health devices and services. Coming in a future update.',
                  icon: Icons.extension_outlined,
                ),
              ),
            ),
          ),

          const Divider(color: AppColors.divider, height: 32),

          // ── General Settings ────────────────────────────────────────
          _SettingsTile(
            icon: Icons.settings_outlined,
            title: 'General Settings',
            subtitle: 'Device, unit, language',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const _GeneralSettingsScreen()),
            ),
          ),

          // ── Integrations ───────────────────────────────────────────
          _SettingsTile(
            icon: Icons.sync_alt,
            title: 'Integrations',
            subtitle: user != null
                ? 'Cloud sync enabled'
                : 'Sign in to enable cloud sync',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const _IntegrationsScreen()),
            ),
          ),

          const Divider(color: AppColors.divider, height: 32),

          // ── About ──────────────────────────────────────────────────
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Terms & privacy',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const _AboutScreen()),
            ),
          ),

          // ── Support ────────────────────────────────────────────────
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Support',
            subtitle: 'Help & troubleshooting',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const _SupportScreen()),
            ),
          ),

          // ── App Versioning ─────────────────────────────────────────
          _SettingsTile(
            icon: Icons.system_update_outlined,
            title: 'App Version',
            subtitle: 'v1.0.0 (MVP)',
            trailing: const SizedBox.shrink(),
            onTap: () {},
          ),

          const Divider(color: AppColors.divider, height: 32),

          // ── Device ─────────────────────────────────────────────────
          _SettingsTile(
            icon: connected
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled,
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

          const SizedBox(height: 16),

          // ── Log Out ────────────────────────────────────────────────
          _SettingsTile(
            icon: Icons.logout,
            title: 'Log Out',
            subtitle: user != null
                ? 'Signed in as ${user.email ?? user.phone ?? 'user'}'
                : 'Not signed in',
            iconColor: AppColors.error,
            onTap: () => _confirmLogOut(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogOut(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      // Not signed in — nothing to log out of.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not signed in.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Log out?'),
        content: const Text(
          'Your health data stays on this device. Cloud sync will pause '
          'until you sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yes, log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(supabaseClientProvider).auth.signOut();
      if (context.mounted) {
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile View
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileViewScreen extends ConsumerWidget {
  const _ProfileViewScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('User Profile'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Failed to load profile: $e',
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline,
                          size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      const Text(
                        'No profile set up yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => context.push('/onboarding'),
                        child: const Text('Set up profile'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final age = _ageFromDob(profile.dateOfBirth);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Avatar ──────────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: () => _showAvatarSheet(context),
                    child: Stack(
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.surface,
                          child: Icon(Icons.person,
                              size: 40, color: AppColors.primary),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Nickname ────────────────────────────────────────
                _EditableProfileRow(
                  icon: Icons.badge_outlined,
                  label: 'Nickname',
                  value: '--',
                  onTap: () async {
                    final ctrl = TextEditingController();
                    final name = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Nickname'),
                        content: TextField(
                          controller: ctrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Enter nickname',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              final n = ctrl.text.trim();
                              Navigator.pop(ctx, n.isEmpty ? null : n);
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    );
                    ctrl.dispose();
                    if (name != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Nickname set to "$name"')),
                      );
                    }
                  },
                ),

                // ── DOB ─────────────────────────────────────────────
                _EditableProfileRow(
                  icon: Icons.cake_outlined,
                  label: 'Date of Birth',
                  value: profile.dateOfBirth != null
                      ? '${profile.dateOfBirth!.year}-${profile.dateOfBirth!.month.toString().padLeft(2, '0')}-${profile.dateOfBirth!.day.toString().padLeft(2, '0')}'
                      : '--',
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          profile.dateOfBirth ?? DateTime(1990, 1, 1),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      await _saveProfile(ref, profile.copyWith(
                          dateOfBirth: picked));
                      ref.invalidate(userProfileProvider);
                    }
                  },
                ),

                // ── Age (read-only, derived from DOB) ───────────────
                _EditableProfileRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Age',
                  value: age != null ? '$age years' : '--',
                  showChevron: false,
                  onTap: () {},
                ),

                // ── Gender ──────────────────────────────────────────
                _EditableProfileRow(
                  icon: Icons.wc_outlined,
                  label: 'Gender',
                  value: _sexLabel(profile.sexAtBirth),
                  onTap: () async {
                    final picked = await showDialog<SexAtBirth>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Gender'),
                        children: [
                          for (final sex in SexAtBirth.values)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, sex),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      sex == profile.sexAtBirth
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(_sexLabel(sex)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                    if (picked != null) {
                      await _saveProfile(ref, profile.copyWith(
                          sexAtBirth: picked));
                      ref.invalidate(userProfileProvider);
                    }
                  },
                ),

                // ── Height ──────────────────────────────────────────
                _EditableProfileRow(
                  icon: Icons.height,
                  label: 'Height',
                  value: profile.heightCm != null
                      ? '${profile.heightCm!.round()} cm'
                      : '--',
                  onTap: () async {
                    final ctrl = TextEditingController(
                        text: profile.heightCm?.round().toString() ?? '');
                    final result = await showDialog<double>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Height'),
                        content: TextField(
                          controller: ctrl,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            suffixText: 'cm',
                            hintText: '170',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              final v = double.tryParse(ctrl.text);
                              Navigator.pop(ctx, v);
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    );
                    ctrl.dispose();
                    if (result != null && result > 0) {
                      await _saveProfile(ref, profile.copyWith(
                          heightCm: result));
                      ref.invalidate(userProfileProvider);
                    }
                  },
                ),

                // ── Weight ──────────────────────────────────────────
                _EditableProfileRow(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Weight',
                  value: profile.weightKg != null
                      ? '${profile.weightKg!.round()} kg'
                      : '--',
                  onTap: () async {
                    final ctrl = TextEditingController(
                        text: profile.weightKg?.round().toString() ?? '');
                    final result = await showDialog<double>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Weight'),
                        content: TextField(
                          controller: ctrl,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            suffixText: 'kg',
                            hintText: '70',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              final v = double.tryParse(ctrl.text);
                              Navigator.pop(ctx, v);
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    );
                    ctrl.dispose();
                    if (result != null && result > 0) {
                      await _saveProfile(ref, profile.copyWith(
                          weightKg: result));
                      ref.invalidate(userProfileProvider);
                    }
                  },
                ),

                const SizedBox(height: 8),
                const Divider(color: AppColors.divider, height: 32),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Account & Data',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),

                // ── Monitoring ────────────────────────────────────────
                _EditableProfileRow(
                  icon: Icons.speed_outlined,
                  label: 'Monitoring',
                  value: 'Sample rates',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const MonitoringScreen(),
                    ),
                  ),
                ),

                // ── Notifications ─────────────────────────────────────
                _EditableProfileRow(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  value: '',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),

                // ── Change Credential ─────────────────────────────────
                _EditableProfileRow(
                  icon: Icons.key_outlined,
                  label: 'Change Credential',
                  value: '',
                  onTap: () => _showChangeCredentialDialog(context),
                ),

                // ── Delete Profile ────────────────────────────────────
                _EditableProfileRow(
                  icon: Icons.delete_forever_outlined,
                  iconColor: AppColors.error,
                  label: 'Delete Profile',
                  value: '',
                  onTap: () => _showDeleteProfileDialog(context, ref),
                ),

                // ── CSV Export ────────────────────────────────────────
                _EditableProfileRow(
                  icon: Icons.file_download_outlined,
                  label: 'Export Data (CSV)',
                  value: '',
                  onTap: () => _showCsvExportDialog(context),
                ),

                // ── Clear Cache ───────────────────────────────────────
                _EditableProfileRow(
                  icon: Icons.cleaning_services_outlined,
                  label: 'Clear Cache',
                  value: '',
                  onTap: () => _showClearCacheDialog(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveProfile(WidgetRef ref, UserProfile profile) async {
    await ref.read(userRepositoryProvider).upsertProfile(profile);
  }

  String _sexLabel(SexAtBirth sex) => switch (sex) {
        SexAtBirth.female => 'Female',
        SexAtBirth.male => 'Male',
        SexAtBirth.unknown => 'Not set',
      };

  int? _ageFromDob(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  void _showAvatarSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Image picker will be available in a future update.'),
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Image picker will be available in a future update.'),
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.close, color: AppColors.textSecondary),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showChangeCredentialDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Change Credential'),
        content: const Text('Change your sign-in credentials?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/auth');
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteProfileDialog(
      BuildContext context, WidgetRef ref) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Profile'),
        content: const Text(
          'This will permanently delete your profile and health data from this device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Are you sure?'),
        content: const Text(
          'This is your last chance. All profile data will be erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (second != true || !context.mounted) return;

    try {
      // Delete profile row from Drift database
      final database = ref.read(db.appDatabaseProvider);
      await (database.delete(database.userProfiles)
            ..where(
                (t) => t.userId.equals(ActiveSession.defaultUserId)))
          .go();
      ref.invalidate(userProfileProvider);
      if (context.mounted) {
        context.go('/onboarding');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete profile: $e')),
        );
      }
    }
  }

  void _showCsvExportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Export Data'),
        content: const Text('Export health data as CSV?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('CSV export will be available in a future update.'),
                ),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear Cache'),
        content: const Text(
            "Clear cached data? This won't delete your health records."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}

class _EditableProfileRow extends StatelessWidget {
  const _EditableProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.showChevron = true,
    this.iconColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool showChevron;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 22),
        title: Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            if (showChevron) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 20),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coming Soon (reusable for AI Insights & HLTH Plugs)
// ─────────────────────────────────────────────────────────────────────────────

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({
    required this.title,
    required this.description,
    required this.icon,
  });
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(title),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: AppColors.primary),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                          color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// General Settings (Device · Unit · Language)
// ─────────────────────────────────────────────────────────────────────────────

class _GeneralSettingsScreen extends StatefulWidget {
  const _GeneralSettingsScreen();

  @override
  State<_GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<_GeneralSettingsScreen> {
  String _unitSystem = 'Metric (kg, cm, km)';
  String _language = 'English';

  static const _unitOptions = [
    'Metric (kg, cm, km)',
    'Imperial (lb, in, mi)',
  ];
  static const _languageOptions = [
    'English',
    'Chinese (Simplified)',
    'Spanish',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _unitSystem =
          prefs.getString('unit_system') ?? 'Metric (kg, cm, km)';
      _language = prefs.getString('app_language') ?? 'English';
    });
  }

  Future<void> _showUnitDialog() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Unit System'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _unitOptions
              .map(
                (opt) => ListTile(
                  title: Text(opt),
                  leading: Icon(
                    opt == _unitSystem
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onTap: () => Navigator.pop(ctx, opt),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (picked != null && picked != _unitSystem) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('unit_system', picked);
      setState(() => _unitSystem = picked);
    }
  }

  Future<void> _showLanguageDialog() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _languageOptions
              .map(
                (opt) => ListTile(
                  title: Text(opt),
                  leading: Icon(
                    opt == _language
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onTap: () => Navigator.pop(ctx, opt),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (picked == null || picked == _language || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Change language?'),
        content: const Text('The app will restart to apply the change.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', picked);
    setState(() => _language = picked);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Language changed. Restart to apply.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('General Settings'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _GeneralTile(
              icon: Icons.watch_outlined,
              title: 'Device Settings',
              subtitle: 'Band preferences and firmware',
              onTap: () => context.push('/settings/device'),
            ),
            _GeneralTile(
              icon: Icons.system_update,
              title: 'Firmware Update',
              subtitle: 'Up to date',
              showChevron: false,
              onTap: () {},
            ),
            _GeneralTile(
              icon: Icons.straighten,
              title: 'Units',
              subtitle: _unitSystem,
              onTap: _showUnitDialog,
            ),
            _GeneralTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: _language,
              onTap: _showLanguageDialog,
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneralTile extends StatelessWidget {
  const _GeneralTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: AppColors.textTertiary, fontSize: 12)),
        trailing: showChevron
            ? const Icon(Icons.chevron_right, color: AppColors.textTertiary)
            : null,
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Integrations
// ─────────────────────────────────────────────────────────────────────────────

class _IntegrationsScreen extends ConsumerWidget {
  const _IntegrationsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Integrations'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Cloud sync
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        user != null ? Icons.cloud_done : Icons.cloud_off,
                        color: user != null
                            ? AppColors.success
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supabase Cloud Sync',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user != null
                                  ? 'Connected as ${user.email ?? user.phone ?? 'user'}'
                                  : 'Not connected — sign in to enable',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (user == null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.push('/auth'),
                        child: const Text('Sign in'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Apple Health
            _IntegrationTile(
              icon: Icons.health_and_safety,
              title: 'Apple Health',
              subtitle: 'Not connected',
              onTap: () => _showIntegrationDialog(
                context,
                'Apple Health',
                'Connect to Apple Health?',
                'Apple Health integration coming soon',
              ),
            ),
            const SizedBox(height: 8),

            // Google Fit
            _IntegrationTile(
              icon: Icons.fitness_center,
              title: 'Google Fit',
              subtitle: 'Not connected',
              onTap: () => _showIntegrationDialog(
                context,
                'Google Fit',
                'Connect to Google Fit?',
                'Google Fit integration coming soon',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showIntegrationDialog(
    BuildContext context,
    String name,
    String question,
    String snackbarMessage,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(name),
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(snackbarMessage)),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textTertiary),
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// About (Terms & Privacy)
// ─────────────────────────────────────────────────────────────────────────────

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('About'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(
              child: Column(
                children: [
                  Icon(Icons.favorite, color: AppColors.primary, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'HLTH',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'v1.0.0 (MVP)',
                    style: TextStyle(
                        color: AppColors.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _AboutTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _LegalTextScreen(
                    title: 'Terms of Service',
                    body: _kTermsText,
                  ),
                ),
              ),
            ),
            _AboutTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _LegalTextScreen(
                    title: 'Privacy Policy',
                    body: _kPrivacyText,
                  ),
                ),
              ),
            ),
            _AboutTile(
              icon: Icons.gavel_outlined,
              title: 'Open Source Licenses',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'HLTH',
                applicationVersion: 'v1.0.0',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textTertiary),
        onTap: onTap,
      ),
    );
  }
}

class _LegalTextScreen extends StatelessWidget {
  const _LegalTextScreen({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(title),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
          ),
        ),
      ),
    );
  }
}

const _kTermsText = '''
HLTH App — Terms of Service

Last updated: June 2026

1. Acceptance of Terms
By using the HLTH app, you agree to these Terms of Service. If you do not agree, do not use the app.

2. Product Description
HLTH is a wellness companion app designed to work with the HLTH smart band. It provides health metrics including heart rate, blood pressure estimates, sleep tracking, and activity monitoring.

3. Not Medical Device
The HLTH app and band are wellness products, NOT medical devices. Data provided is for informational and educational purposes only. Do not use this app to diagnose, treat, or prevent any medical condition. Always consult a qualified healthcare professional for medical advice.

4. Data & Privacy
Your health data is stored locally on your device by default. Cloud sync is optional and requires a Supabase account. See our Privacy Policy for details on how we handle your data.

5. Limitation of Liability
HLTH and its affiliates are not liable for any health decisions made based on data from this app. Use at your own risk.

6. Changes to Terms
We may update these terms from time to time. Continued use of the app constitutes acceptance of updated terms.
''';

const _kPrivacyText = '''
HLTH App — Privacy Policy

Last updated: June 2026

1. Data Collection
The HLTH app collects health metrics from your HLTH smart band, including heart rate, blood pressure, sleep data, activity data, HRV, SpO2, and stress levels. Profile data (DOB, sex, height, weight) is collected during onboarding for calibration purposes.

2. Local Storage
All health data is stored locally on your device using an encrypted SQLite database. No data leaves your device unless you explicitly enable cloud sync.

3. Cloud Sync (Optional)
If you create a Supabase account, your data is synced to our secure cloud servers for cross-device access. You can delete your cloud data at any time from Settings.

4. No Third-Party Sharing
We do not sell, share, or provide your health data to third parties. Period.

5. Data Retention
Local data remains on your device until you delete the app. Cloud data is retained while your account is active and can be deleted on request.

6. GDPR Compliance
If you are in the EU, you have the right to access, rectify, or delete your personal data. Contact support@hlth.app for data requests.

7. Contact
For privacy inquiries, contact: support@hlth.app
''';

// ─────────────────────────────────────────────────────────────────────────────
// Support
// ─────────────────────────────────────────────────────────────────────────────

class _SupportScreen extends StatefulWidget {
  const _SupportScreen();

  @override
  State<_SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<_SupportScreen> {
  bool _faqExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Support'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.help_outline,
                size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'How can we help?',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── FAQ Section ────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.quiz_outlined,
                        color: AppColors.textSecondary),
                    title: const Text('FAQ'),
                    trailing: Icon(
                      _faqExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: AppColors.textTertiary,
                    ),
                    onTap: () =>
                        setState(() => _faqExpanded = !_faqExpanded),
                  ),
                  if (_faqExpanded) ...[
                    const Divider(color: AppColors.divider, height: 1),
                    _SupportTile(
                      icon: Icons.bluetooth_searching,
                      title: 'Band won\'t connect',
                      body:
                          '1. Make sure the band is charged and within range.\n'
                          '2. Toggle Bluetooth off and on.\n'
                          '3. Go to Settings \u2192 HLTH Band \u2192 tap to reconnect.\n'
                          '4. If the band is paired to another phone, forget it from that phone first.',
                    ),
                    _SupportTile(
                      icon: Icons.favorite_border,
                      title: 'Heart rate shows "--"',
                      body:
                          'Wear the band snugly on your index finger. Wait 30\u201360 seconds for the sensor to stabilize. '
                          'If it persists, try Measure Now from the Heart Rate screen.',
                    ),
                    _SupportTile(
                      icon: Icons.sync_problem,
                      title: 'Data not syncing',
                      body:
                          'Data syncs when the band is connected. Open the app with the band nearby '
                          'and wait for the sync indicator to appear. Pull down to refresh on any metric screen.',
                    ),
                    _SupportTile(
                      icon: Icons.battery_alert,
                      title: 'Band battery drains fast',
                      body:
                          'Scheduled BP monitoring (every 15 min) and continuous HR can drain the battery faster. '
                          'Consider using hourly BP intervals and letting HR run on the band\'s default schedule.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Get Help ───────────────────────────────────────────
            _SupportActionTile(
              icon: Icons.chat_outlined,
              title: 'Get Help',
              subtitle: 'Chat with support',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Live chat support coming soon')),
                );
              },
            ),
            const SizedBox(height: 8),

            // ── Submit Ticket ──────────────────────────────────────
            _SupportActionTile(
              icon: Icons.confirmation_number_outlined,
              title: 'Submit Ticket',
              subtitle: 'Report an issue',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _SubmitTicketScreen(
                      title: 'Submit Ticket'),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Leave Feedback ─────────────────────────────────────
            _SupportActionTile(
              icon: Icons.rate_review_outlined,
              title: 'Leave Feedback',
              subtitle: 'Tell us what you think',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _SubmitTicketScreen(
                      title: 'Leave Feedback'),
                ),
              ),
            ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Icon(Icons.email_outlined,
                      color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                    'Still need help?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Contact us at support@hlth.app',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportActionTile extends StatelessWidget {
  const _SupportActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary, size: 22),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textTertiary),
        onTap: onTap,
      ),
    );
  }
}

class _SubmitTicketScreen extends StatefulWidget {
  const _SubmitTicketScreen({required this.title});
  final String title;

  @override
  State<_SubmitTicketScreen> createState() => _SubmitTicketScreenState();
}

class _SubmitTicketScreenState extends State<_SubmitTicketScreen> {
  final _subjectCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.title),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _subjectCtrl,
              decoration: InputDecoration(
                labelText: 'Subject',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final subject = _subjectCtrl.text.trim();
                  if (subject.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a subject')),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.title == 'Leave Feedback'
                          ? 'Feedback submitted'
                          : 'Ticket submitted'),
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.textSecondary, size: 22),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        collapsedIconColor: AppColors.textTertiary,
        iconColor: AppColors.primary,
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
