import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Reminders screen: sedentary reminder configuration and haptic alarm.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _sedentaryEnabled = false;
  int _sedentaryInterval = 60;
  static const _intervalOptions = [30, 60, 90, 120];

  // Single alarm slot for MVP
  TimeOfDay? _alarmTime;
  bool _alarmEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmJson = prefs.getString('reminder_haptic_alarm');
    Map<String, dynamic>? alarmData;
    if (alarmJson != null) {
      try {
        alarmData = jsonDecode(alarmJson) as Map<String, dynamic>;
      } catch (_) {}
    }
    setState(() {
      _sedentaryEnabled =
          prefs.getBool('reminder_sedentary_enabled') ?? false;
      _sedentaryInterval =
          prefs.getInt('reminder_sedentary_interval_min') ?? 60;
      if (alarmData != null) {
        _alarmTime = TimeOfDay(
          hour: alarmData['hour'] as int,
          minute: alarmData['minute'] as int,
        );
        _alarmEnabled = alarmData['enabled'] as bool? ?? false;
      }
    });
  }

  Future<void> _saveSedentaryPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_sedentary_enabled', _sedentaryEnabled);
    await prefs.setInt('reminder_sedentary_interval_min', _sedentaryInterval);
  }

  Future<void> _saveAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    if (_alarmTime == null) {
      await prefs.remove('reminder_haptic_alarm');
    } else {
      final data = jsonEncode({
        'hour': _alarmTime!.hour,
        'minute': _alarmTime!.minute,
        'enabled': _alarmEnabled,
      });
      await prefs.setString('reminder_haptic_alarm', data);
    }
  }

  Future<void> _pickAlarmTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _alarmTime ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _alarmTime = picked;
        _alarmEnabled = true;
      });
      _saveAlarm();
    }
  }

  Future<void> _deleteAlarm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete alarm?'),
        content: const Text('This will remove the haptic alarm.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _alarmTime = null;
        _alarmEnabled = false;
      });
      _saveAlarm();
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Reminders'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Sedentary Reminders ──────────────────────────────────
            Text(
              'Sedentary Reminders',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable sedentary reminders'),
                    subtitle: const Text(
                      'Remind you to move after sitting too long',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    value: _sedentaryEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) {
                      setState(() => _sedentaryEnabled = v);
                      _saveSedentaryPrefs();
                    },
                  ),
                  if (_sedentaryEnabled) ...[
                    const Divider(color: AppColors.divider),
                    const SizedBox(height: 8),
                    const Text(
                      'Remind every:',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _intervalOptions.map((min) {
                        final selected = _sedentaryInterval == min;
                        return ChoiceChip(
                          label: Text('$min min'),
                          selected: selected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceLight,
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          onSelected: (_) {
                            setState(() => _sedentaryInterval = min);
                            _saveSedentaryPrefs();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          _saveSedentaryPrefs();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reminders saved')),
                          );
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Haptic Alarm ─────────────────────────────────────────
            Text(
              'Haptic Alarm',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_alarmTime != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.alarm,
                            color: AppColors.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickAlarmTime,
                            child: Text(
                              _formatTime(_alarmTime!),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        Switch(
                          value: _alarmEnabled,
                          activeTrackColor: AppColors.primary,
                          onChanged: (v) {
                            setState(() => _alarmEnabled = v);
                            _saveAlarm();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.error, size: 22),
                          onPressed: _deleteAlarm,
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'No alarm set',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickAlarmTime,
                      icon: const Icon(Icons.add),
                      label: Text(
                          _alarmTime != null ? 'Change alarm' : 'Add alarm'),
                    ),
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
