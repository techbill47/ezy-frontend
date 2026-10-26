import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../health_screen.dart';
import '../models/app_user.dart';
import '../services/ble_service.dart';
import '../services/queue_service.dart';
import '../services/session_service.dart';
import 'ble_test_screen.dart';
import 'courses_screen.dart';
import 'start_session_screen.dart';
import 'past_sessions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  static final Map<int, String> _departmentNameCache = {};
  final BleService _ble = BleService();
  bool _marking = false;
  bool _departmentLoading = false;
  String? _markMessage, _markError;
  Future<void> _logout() async {
    await context.read<SessionService>().clear();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }
  String? _departmentName, _departmentError;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) async { await _refreshIfOnline(); await _ensureDepartmentName(); }); }
  Future<void> _refreshIfOnline() async {
    final session = context.read<SessionService>();
    try {
      if ((await Connectivity().checkConnectivity()).contains(ConnectivityResult.none)) return;
      final data = await ApiClient(token: session.token).get('/api/me');
      if (data is Map && mounted) {
        final serverUser = AppUser.fromJson(Map<String, dynamic>.from(data));
        final savedName = session.user?.departmentName ?? '';
        await session.updateUser(AppUser(id: serverUser.id, matricule: serverUser.matricule, fullName: serverUser.fullName, role: serverUser.role, departmentId: serverUser.departmentId, departmentName: serverUser.departmentName.isNotEmpty ? serverUser.departmentName : savedName, year: serverUser.year));
      }
    } catch (_) { /* Keep the saved profile when refresh is unavailable. */ }
  }
  Future<void> _ensureDepartmentName() async {
    final session = context.read<SessionService>();
    final user = session.user;
    if (user == null || user.departmentName.trim().isNotEmpty) {
      if (mounted && user?.departmentName.isNotEmpty == true) setState(() => _departmentName = user!.departmentName);
      return;
    }
    final cached = _departmentNameCache[user.departmentId];
    if (cached != null) {
      setState(() => _departmentName = cached);
      await session.updateUser(AppUser(id: user.id, matricule: user.matricule, fullName: user.fullName, role: user.role, departmentId: user.departmentId, departmentName: cached, year: user.year));
      return;
    }
    setState(() { _departmentLoading = true; _departmentError = null; });
    try {
      final response = await ApiClient(token: session.token).get('/api/departments');
      if (response is! List) throw ApiException('The server returned an invalid department list.');
      for (final item in response.whereType<Map>()) {
        final id = int.tryParse('${item['id']}');
        final name = '${item['name'] ?? ''}'.trim();
        if (id != null && name.isNotEmpty) _departmentNameCache[id] = name;
      }
      final name = _departmentNameCache[user.departmentId];
      if (name == null) throw ApiException('Your department was not found in the department list.');
      if (mounted) setState(() => _departmentName = name);
      await session.updateUser(AppUser(id: user.id, matricule: user.matricule, fullName: user.fullName, role: user.role, departmentId: user.departmentId, departmentName: name, year: user.year));
    } catch (error) {
      if (mounted) setState(() => _departmentError = 'Could not load department name: $error');
    } finally { if (mounted) setState(() => _departmentLoading = false); }
  }
  Future<void> _markAttendance() async {
    final user = context.read<SessionService>().user;
    final queue = context.read<QueueService>();
    if (user == null || _marking) return;
    setState(() { _marking = true; _markError = null; _markMessage = 'Scanning for your class session for up to 10 seconds…'; });
    try {
      final signal = await _ble.scanForSession(context, user.departmentId, user.year);
      if (signal == null) {
        if (mounted) setState(() { _markMessage = null; _markError = _ble.heardOtherClass ? 'No session found for your class' : 'No session found. Move closer and try again.'; });
      } else {
        final detectedAt = DateTime.now().toUtc().toIso8601String();
        final added = await queue.addMark(signal.code, detectedAt, user.id);
        if (mounted) setState(() { _markMessage = added ? 'Marked — ${signal.code}\n${DateTime.parse(detectedAt).toLocal()}' : 'This session code is already in your recent marks: ${signal.code}'; _markError = null; });
      }
    } catch (error) { if (mounted) setState(() { _markMessage = null; _markError = error.toString(); }); }
    finally { if (mounted) setState(() => _marking = false); }
  }
  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionService>().user;
    final queue = context.watch<QueueService>();
    return Scaffold(appBar: AppBar(title: const Text('EZY'), actions: [TextButton(onPressed: _logout, child: const Text('Logout'))]), body: ListView(padding: const EdgeInsets.all(24), children: [
      Text(user?.fullName ?? 'User', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      _detail('Matricule', user?.matricule), _detail('Role', user?.role), _detail('Department', _departmentLoading ? 'Loading…' : _departmentName ?? _departmentError ?? user?.departmentName), _detail('Year', user?.year.toString()),
      const SizedBox(height: 24),
      if (user?.role == 'coordinator') SizedBox(height: 64, child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const StartSessionScreen())), child: const Text('Start session', style: TextStyle(fontSize: 20)))),
      if (user?.role == 'coordinator') SizedBox(height: 56, child: OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PastSessionsScreen(user: user!))), child: const Text('Past sessions'))),
      if (user?.role == 'student') ...[
        SizedBox(height: 64, child: FilledButton(onPressed: _marking ? null : _markAttendance, child: _marking ? const CircularProgressIndicator() : const Text('Mark attendance', style: TextStyle(fontSize: 20)))),
        if (_markMessage != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_markMessage!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
        if (_markError != null) ...[Text(_markError!, style: TextStyle(color: Theme.of(context).colorScheme.error)), OutlinedButton(onPressed: _marking ? null : _markAttendance, child: const Text('Retry'))],
        const SizedBox(height: 12),
        Text('Pending sync: ${queue.pendingFor(user?.id ?? '')}', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 48, child: OutlinedButton(onPressed: queue.syncing ? null : queue.syncNow, child: Text(queue.syncing ? 'Syncing…' : 'Sync now'))),
        if (queue.lastSyncResult != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(queue.lastSyncResult!)),
        const SizedBox(height: 12), Text('Recent marks', style: Theme.of(context).textTheme.titleMedium),
        if (queue.historyFor(user?.id ?? '').isEmpty) const Text('No marks yet.'),
        ...queue.historyFor(user?.id ?? '').map((mark) => ListTile(contentPadding: EdgeInsets.zero, title: Text('${mark['sessionCode']}'), subtitle: Text('${DateTime.tryParse('${mark['detectedAt']}')?.toLocal() ?? mark['detectedAt']}${mark['status'] == 'rejected' ? '\n${mark['reason']}' : ''}'), trailing: Text('${mark['status']}'))),
      ],
      SizedBox(height: 56, child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CoursesScreen())), child: const Text('My courses'))),
      SizedBox(height: 56, child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HealthScreen())), child: const Text('Connection check'))),
      OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const BleTestScreen())), child: const Text('BLE test')),
    ]));
  }
  Widget _detail(String title, String? value) => ListTile(contentPadding: EdgeInsets.zero, title: Text(title), subtitle: Text(value?.isNotEmpty == true ? value! : 'Unavailable'));
}
