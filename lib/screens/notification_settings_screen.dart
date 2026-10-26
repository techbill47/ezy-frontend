import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/surfaces.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _loading = true, _attendanceEnabled = true, _sessionEnabled = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final service = NotificationService.instance;
    final attendance = await service.attendanceEnabled();
    final session = await service.sessionEnabled();
    if (mounted) setState(() { _attendanceEnabled = attendance; _sessionEnabled = session; _loading = false; });
  }

  Future<void> _setAttendance(bool enabled) async {
    if (enabled && !await NotificationService.instance.requestPermission(context)) return;
    await NotificationService.instance.setAttendanceEnabled(enabled);
    if (mounted) setState(() => _attendanceEnabled = enabled);
  }
  Future<void> _setSession(bool enabled) async {
    if (enabled && !await NotificationService.instance.requestPermission(context)) return;
    await NotificationService.instance.setSessionEnabled(enabled);
    if (mounted) setState(() => _sessionEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(18), children: [
      Text('Notifications', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text('Choose which EZY updates can appear on this phone.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 16),
      AppCard(padding: EdgeInsets.zero, child: SwitchListTile(title: const Text('Attendance'), subtitle: const Text('Marks, sync updates, and rejected records'), value: _attendanceEnabled, onChanged: _setAttendance)),
      AppCard(padding: EdgeInsets.zero, child: SwitchListTile(title: const Text('Session'), subtitle: const Text('Ending reminders and coordinator session status'), value: _sessionEnabled, onChanged: _setSession)),
    ]),
  );
}
