import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../health_screen.dart';
import '../models/app_user.dart';
import '../services/session_service.dart';
import 'ble_test_screen.dart';
import 'courses_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _refreshIfOnline()); }
  Future<void> _refreshIfOnline() async {
    final session = context.read<SessionService>();
    try {
      if ((await Connectivity().checkConnectivity()).contains(ConnectivityResult.none)) return;
      final data = await ApiClient(token: session.token).get('/api/me');
      if (data is Map && mounted) await session.updateUser(AppUser.fromJson(Map<String, dynamic>.from(data)));
    } catch (_) { /* Keep the saved profile when refresh is unavailable. */ }
  }
  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionService>().user;
    return Scaffold(appBar: AppBar(title: const Text('EZY'), actions: [TextButton(onPressed: () => context.read<SessionService>().clear(), child: const Text('Logout'))]), body: ListView(padding: const EdgeInsets.all(24), children: [
      Text(user?.fullName ?? 'User', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      _detail('Matricule', user?.matricule), _detail('Role', user?.role), _detail('Department', user?.departmentName), _detail('Year', user?.year.toString()),
      const SizedBox(height: 24),
      SizedBox(height: 56, child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CoursesScreen())), child: const Text('My courses'))),
      SizedBox(height: 56, child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HealthScreen())), child: const Text('Connection check'))),
      OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const BleTestScreen())), child: const Text('BLE test')),
    ]));
  }
  Widget _detail(String title, String? value) => ListTile(contentPadding: EdgeInsets.zero, title: Text(title), subtitle: Text(value?.isNotEmpty == true ? value! : 'Unavailable'));
}
