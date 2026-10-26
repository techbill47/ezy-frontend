import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/app_user.dart';
import '../services/session_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/offline_banner.dart';
import '../widgets/surfaces.dart';
import 'courses_screen.dart';
import 'past_sessions_screen.dart';
import 'start_session_screen.dart';
import 'student_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final Map<int, String> _departmentNameCache = {};
  bool _departmentLoading = false;
  String? _departmentName, _departmentError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshIfOnline();
      await _ensureDepartmentName();
    });
  }

  Future<void> _logout() async {
    await context.read<SessionService>().clear();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

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
    final firstName = user?.fullName.trim().split(RegExp(r'\s+')).first ?? 'Coordinator';
    final department = _departmentLoading ? 'Loading department…' : _departmentName ?? user?.departmentName ?? 'Department unavailable';
    return AppScaffold(
      appBar: AppBar(title: const Text('EZY'), actions: [TextButton(onPressed: _logout, child: const Text('Logout'))]),
      body: Column(children: [
        OfflineBanner(role: user?.role ?? 'coordinator'),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(22, 26, 22, 28), children: [
          Text('Hello, $firstName', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: StatusPill(label: '$department  •  Year ${user?.year ?? ''}', kind: StatusKind.info, icon: Icons.school_outlined)),
          if (_departmentError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_departmentError!, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 32),
          PrimaryButton(label: 'Start session', icon: Icons.sensors, onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const StartSessionScreen()))),
          const SizedBox(height: 18),
          AppCard(onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PastSessionsScreen(user: user!))), child: const Row(children: [Icon(Icons.history), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Past sessions'), SizedBox(height: 3), Text('Review attendance and export sheets')])), Icon(Icons.chevron_right)])),
          AppCard(onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CoursesScreen())), child: const Row(children: [Icon(Icons.menu_book_outlined), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('My courses'), SizedBox(height: 3), Text('View your class courses')])), Icon(Icons.chevron_right)])),
        ])),
      ]),
    );
  }
}
