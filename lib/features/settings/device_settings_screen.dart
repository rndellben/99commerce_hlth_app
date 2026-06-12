import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/device.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Dedicated "My Device" screen. Shows the currently-bound band's info and
/// exposes Rename + Forget actions. Required for HLTH device-binding spec:
/// every band is bound to a user_id at first pair; on subsequent connects
/// the BLE Debug screen rejects any band whose MAC doesn't match the
/// bound one. Use Forget to break the binding and re-pair a different
/// band.
class DeviceSettingsScreen extends ConsumerStatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  ConsumerState<DeviceSettingsScreen> createState() =>
      _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends ConsumerState<DeviceSettingsScreen> {
  Device? _bound;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(deviceRepositoryProvider);
    final bound = await repo.getActiveForUser(ActiveSession.defaultUserId);
    if (!mounted) return;
    setState(() {
      _bound = bound;
      _loading = false;
    });
  }

  Future<void> _rename() async {
    final bound = _bound;
    if (bound == null) return;
    final controller = TextEditingController(text: bound.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MAC: ${bound.macAddress ?? '—'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Friendly name',
                hintText: 'My Ring',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await ref
        .read(deviceRepositoryProvider)
        .rename(deviceId: bound.id, displayName: newName);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed to "$newName"')),
      );
    }
  }

  Future<void> _forget() async {
    final bound = _bound;
    if (bound == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget this device?'),
        content: Text(
          'You will need to re-pair "${bound.displayName}" '
          '(MAC ${bound.macAddress ?? '—'}) before the app will sync from '
          'it again. Stored health data is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(deviceRepositoryProvider).deactivate(bound.id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device forgotten. Re-pair from BLE Debug.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Device')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bound == null
              ? _buildEmptyState(context)
              : _buildBoundState(context, _bound!),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No band paired yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Pair your HLTH band from the BLE Debug screen to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.bluetooth),
              label: const Text('Open BLE Debug'),
              onPressed: () => context.push('/debug'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoundState(BuildContext context, Device d) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bluetooth_connected,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        d.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _kv('MAC', d.macAddress ?? '—'),
                _kv('Model', d.model ?? '—'),
                _kv('Paired', _fmtDate(d.pairedAt)),
                _kv('Last connected',
                    d.lastConnectedAt == null ? '—' : _fmtDate(d.lastConnectedAt!)),
                _kv('Firmware', d.firmwareVersion ?? '—'),
                _kv('Battery',
                    d.lastBatteryPercent == null ? '—' : '${d.lastBatteryPercent}%'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Rename'),
          subtitle: const Text('Set a friendly name (local only)'),
          onTap: _rename,
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Forget device',
              style: TextStyle(color: Colors.red)),
          subtitle: const Text(
              'Break the pairing. Health data is kept; re-pair from BLE Debug.'),
          onTap: _forget,
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k,
                style: const TextStyle(color: AppColors.textTertiary)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
