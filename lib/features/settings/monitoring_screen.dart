import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Monitoring / Sample Rate configuration screen.
/// Allows per-metric frequency selection and a low-power override.
class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  bool _lowPower = false;
  String _hrInterval = 'Every 15 min';
  String _hrvInterval = 'Every 60 min';
  String _spo2Interval = 'Every 60 min';
  String _bpInterval = 'Every 30 min';
  String _stressInterval = 'Every 60 min';

  static const _hrOptions = [
    'Every 5 min',
    'Every 15 min',
    'Every 30 min',
    'Every 60 min',
  ];
  static const _hrvOptions = [
    'Every 30 min',
    'Every 60 min',
    'Every 2 hours',
  ];
  static const _spo2Options = [
    'Every 30 min',
    'Every 60 min',
  ];
  static const _bpOptions = [
    'Every 15 min',
    'Every 30 min',
    'Every 60 min',
  ];
  static const _stressOptions = [
    'Every 30 min',
    'Every 60 min',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lowPower = prefs.getBool('monitoring_low_power') ?? false;
      _hrInterval = prefs.getString('monitoring_hr_interval') ?? 'Every 15 min';
      _hrvInterval =
          prefs.getString('monitoring_hrv_interval') ?? 'Every 60 min';
      _spo2Interval =
          prefs.getString('monitoring_spo2_interval') ?? 'Every 60 min';
      _bpInterval =
          prefs.getString('monitoring_bp_interval') ?? 'Every 30 min';
      _stressInterval =
          prefs.getString('monitoring_stress_interval') ?? 'Every 60 min';
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _showFrequencyPicker({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: Theme.of(ctx)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            for (final option in options)
              ListTile(
                title: Text(option),
                trailing: option == current
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && picked != current) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Monitoring'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Low Power Mode toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Low Power Mode'),
                subtitle: Text(
                  _lowPower
                      ? 'Auto-optimized settings active'
                      : 'Configure per-metric frequencies below',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                value: _lowPower,
                activeTrackColor: AppColors.primary,
                onChanged: (v) {
                  setState(() => _lowPower = v);
                  _saveBool('monitoring_low_power', v);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Per-metric rows
            _MetricRow(
              icon: Icons.favorite_outlined,
              iconColor: AppColors.heartRate,
              title: 'Heart Rate',
              value: _lowPower ? 'Auto' : _hrInterval,
              enabled: !_lowPower,
              onTap: () => _showFrequencyPicker(
                title: 'Heart Rate Frequency',
                options: _hrOptions,
                current: _hrInterval,
                onSelected: (v) {
                  setState(() => _hrInterval = v);
                  _saveString('monitoring_hr_interval', v);
                },
              ),
            ),
            _MetricRow(
              icon: Icons.timeline,
              iconColor: AppColors.recovery,
              title: 'HRV',
              value: _lowPower ? 'Auto' : _hrvInterval,
              enabled: !_lowPower,
              onTap: () => _showFrequencyPicker(
                title: 'HRV Frequency',
                options: _hrvOptions,
                current: _hrvInterval,
                onSelected: (v) {
                  setState(() => _hrvInterval = v);
                  _saveString('monitoring_hrv_interval', v);
                },
              ),
            ),
            _MetricRow(
              icon: Icons.air,
              iconColor: AppColors.spo2,
              title: 'SpO2',
              value: _lowPower ? 'Auto' : _spo2Interval,
              enabled: !_lowPower,
              onTap: () => _showFrequencyPicker(
                title: 'SpO2 Frequency',
                options: _spo2Options,
                current: _spo2Interval,
                onSelected: (v) {
                  setState(() => _spo2Interval = v);
                  _saveString('monitoring_spo2_interval', v);
                },
              ),
            ),
            _MetricRow(
              icon: Icons.speed,
              iconColor: AppColors.bloodPressure,
              title: 'Blood Pressure',
              value: _lowPower ? 'Auto' : _bpInterval,
              enabled: !_lowPower,
              onTap: () => _showFrequencyPicker(
                title: 'Blood Pressure Frequency',
                options: _bpOptions,
                current: _bpInterval,
                onSelected: (v) {
                  setState(() => _bpInterval = v);
                  _saveString('monitoring_bp_interval', v);
                },
              ),
            ),
            _MetricRow(
              icon: Icons.psychology_outlined,
              iconColor: AppColors.warning,
              title: 'Stress',
              value: _lowPower ? 'Auto' : _stressInterval,
              enabled: !_lowPower,
              onTap: () => _showFrequencyPicker(
                title: 'Stress Frequency',
                options: _stressOptions,
                current: _stressInterval,
                onSelected: (v) {
                  setState(() => _stressInterval = v);
                  _saveString('monitoring_stress_interval', v);
                },
              ),
            ),
            _MetricRow(
              icon: Icons.bedtime_outlined,
              iconColor: AppColors.sleep,
              title: 'Sleep',
              value: 'Tracked automatically overnight',
              enabled: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final bool enabled;
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
        leading: Icon(icon, color: enabled ? iconColor : AppColors.textTertiary,
            size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: enabled
            ? const Icon(Icons.chevron_right, color: AppColors.textTertiary,
                size: 20)
            : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
