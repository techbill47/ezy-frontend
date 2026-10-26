import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../health_screen.dart';
import '../models/app_user.dart';
import '../services/session_service.dart';
import 'ble_test_screen.dart';
import 'courses_screen.dart';
import 'start_session_screen.dart';
import 'past_sessions_screen.dart';
import 'student_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  static final Map<int, String> _departmentNameCache = {};
  bool _departmentLoading = false;
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
  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionService>().user;
    if (user?.role == 'student') return StudentHomeScreen(user: user!);
    return Scaffold(appBar: AppBar(title: const Text('EZY'), actions: [TextButton(onPressed: _logout, child: const Text('Logout'))]), body: ListView(padding: const EdgeInsets.all(24), children: [
      Text(user?.fullName ?? 'User', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      _detail('Matricule', user?.matricule), _detail('Role', user?.role), _detail('Department', _departmentLoading ? 'Loading…' : _departmentName ?? _departmentError ?? user?.departmentName), _detail('Year', user?.year.toString()),
      const SizedBox(height: 24),
      if (user?.role == 'coordinator') SizedBox(height: 64, child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const StartSessionScreen())), child: const Text('Start session', style: TextStyle(fontSize: 20)))),
      if (user?.role == 'coordinator') SizedBox(height: 56, child: OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PastSessionsScreen(user: user!))), child: const Text('Past sessions'))),
      SizedBox(height: 56, child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CoursesScreen())), child: const Text('My courses'))),
      SizedBox(height: 56, child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HealthScreen())), child: const Text('Connection check'))),
      OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const BleTestScreen())), child: const Text('BLE test')),
    ]));
  }
  Widget _detail(String title, String? value) => ListTile(contentPadding: EdgeInsets.zero, title: Text(title), subtitle: Text(value?.isNotEmpty == true ? value! : 'Unavailable'));
}
