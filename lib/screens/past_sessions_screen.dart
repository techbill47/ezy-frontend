import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/app_user.dart';
import '../services/session_service.dart';
import 'session_report_screen.dart';

class PastSessionsScreen extends StatefulWidget {
  const PastSessionsScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<PastSessionsScreen> createState() => _PastSessionsScreenState();
}
class _PastSessionsScreenState extends State<PastSessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiClient(token: context.read<SessionService>().token).get('/api/sessions');
      if (result is! List) throw ApiException('The server returned an invalid sessions list.');
      if (mounted) setState(() => _sessions = result.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList());
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Past sessions')), body: RefreshIndicator(onRefresh: _load, child: _loading ? ListView(children: const [SizedBox(height: 250), Center(child: CircularProgressIndicator())]) : _error != null ? ListView(padding: const EdgeInsets.all(24), children: [Text(_error!), OutlinedButton(onPressed: _load, child: const Text('Retry'))]) : _sessions.isEmpty ? ListView(children: const [SizedBox(height: 200), Center(child: Text('No past sessions yet.'))]) : ListView.separated(padding: const EdgeInsets.all(12), itemCount: _sessions.length, separatorBuilder: (_, _) => const Divider(), itemBuilder: (context, index) {
    final session = _sessions[index];
    final date = DateTime.tryParse('${session['startedAt']}')?.toLocal();
    return ListTile(title: Text('${session['courseCode'] ?? ''} — ${session['courseName'] ?? ''}'), subtitle: Text('${date == null ? 'Date unavailable' : DateFormat('yyyy-MM-dd  HH:mm').format(date)}\nPresent: ${session['presentCount'] ?? 0}'), trailing: const Icon(Icons.chevron_right), isThreeLine: true, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SessionReportScreen(session: session, user: widget.user))));
  })));
}
