import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hlth_app/features/settings/reminders_screen.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Notifications preferences screen.
/// Master toggle, DND, and link to Reminders sub-screen.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _enabled = true;
  bool _dnd = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('notifications_enabled') ?? true;
      _dnd = prefs.getBool('notifications_dnd') ?? false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _toggleNotifications(bool value) async {
    if (!value) {
      // Turning OFF — confirm first
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Turn off all notifications?'),
          content: const Text(
            'You will not receive any health alerts or reminders.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Yes, turn off'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _enabled = value);
    _saveBool('notifications_enabled', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Notifications'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Master toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notifications'),
                subtitle: Text(
                  _enabled ? 'All notifications are on' : 'All notifications are off',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                value: _enabled,
                activeTrackColor: AppColors.primary,
                onChanged: _toggleNotifications,
              ),
            ),
            const SizedBox(height: 12),

            // Do Not Disturb toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Do Not Disturb'),
                    subtitle: const Text(
                      'Silence notifications temporarily',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    value: _dnd,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) {
                      setState(() => _dnd = v);
                      _saveBool('notifications_dnd', v);
                    },
                  ),
                  if (_dnd)
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Notifications are silenced but still recorded',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Reminders row
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.alarm_outlined,
                    color: AppColors.textSecondary, size: 22),
                title: const Text('Reminders'),
                subtitle: const Text(
                  'Sedentary reminders & haptic alarms',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary, size: 20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const RemindersScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
