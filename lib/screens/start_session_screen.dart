import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../services/session_service.dart';
import 'live_session_screen.dart';

class StartSessionScreen extends StatefulWidget {
  const StartSessionScreen({super.key});
  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}
class _StartSessionScreenState extends State<StartSessionScreen> {
  List<Map<String, dynamic>> _courses = [];
  String? _courseId, _error, _notice;
  int? _duration = 60;
  final _customDuration = TextEditingController();
  bool _loading = true, _starting = false;
  @override
  void initState() { super.initState(); _loadCourses(); }
  Future<void> _loadCourses() async {
    setState(() { _loading = true; _error = null; });
    try { final data = await ApiClient(token: context.read<SessionService>().token).get('/api/courses'); if (data is! List) throw ApiException('The server returned an invalid course list.'); if (mounted) setState(() { _courses = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); _courseId ??= _courses.isEmpty ? null : '${_courses.first['id']}'; }); }
    catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _start() async {
    final sessionService = context.read<SessionService>();
    final navigator = Navigator.of(context);
    final duration = _duration ?? int.tryParse(_customDuration.text);
    if (_courseId == null) { setState(() => _error = 'Choose a course.'); return; }
    if (duration == null || duration < 1 || duration > 240) { setState(() => _error = 'Duration must be a whole number from 1 to 240 minutes.'); return; }
    setState(() { _starting = true; _error = null; });
    final api = ApiClient(token: sessionService.token);
    try {
      Map<String, dynamic> session;
      try {
        final result = await api.post('/api/sessions', {'courseId': _courseId, 'durationMinutes': duration});
        session = Map<String, dynamic>.from(result as Map);
      } on ApiException catch (error) {
        if (error.statusCode != 409) rethrow;
        final active = await api.get('/api/sessions/active');
        final activeMap = active is Map ? Map<String, dynamic>.from(active) : null;
        if (activeMap == null || activeMap.isEmpty) throw ApiException('The server reported an active session but did not return it.');
        session = Map<String, dynamic>.from((activeMap['session'] is Map ? activeMap['session'] : activeMap) as Map);
        session['_activeSession'] = true;
      }
      final user = sessionService.user;
      if (!mounted) return;
      final selected = _courses.firstWhere((c) => '${c['id']}' == '${session['courseId'] ?? (session['course'] is Map ? session['course']['id'] : _courseId)}', orElse: () => session['course'] is Map ? Map<String, dynamic>.from(session['course']) : {'id': _courseId, 'code': 'Course', 'name': ''});
      await navigator.push(MaterialPageRoute<void>(builder: (_) => LiveSessionScreen(session: session, course: selected, user: user!, resumed: session['_activeSession'] == true)));
      if (mounted) setState(() => _notice = 'The live session screen was closed, so its BLE broadcast stopped. Tap Start session to resume an active session.');
    } catch (error) { if (mounted) setState(() => _error = error is ApiException && error.statusCode == null ? 'Cannot start a session without internet. The coordinator needs internet only to start the session. ${error.message}' : error.toString()); }
    finally { if (mounted) setState(() => _starting = false); }
  }
  @override
  void dispose() { _customDuration.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Start session')), body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _loadCourses, child: ListView(padding: const EdgeInsets.all(20), children: [
    if (_courses.isEmpty && _error == null) const Text('No courses are available. Add a course before starting a session.'),
    if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    if (_notice != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_notice!)),
    if (_courses.isNotEmpty) DropdownButtonFormField<String>(isExpanded: true, initialValue: _courseId, decoration: const InputDecoration(labelText: 'Course'), items: _courses.map((c) => DropdownMenuItem(value: '${c['id']}', child: Text('${c['code']} — ${c['name']}', overflow: TextOverflow.ellipsis))).toList(), onChanged: _starting ? null : (v) => setState(() => _courseId = v)),
    const SizedBox(height: 18), Text('Duration (minutes)', style: Theme.of(context).textTheme.titleMedium),
    Wrap(spacing: 8, children: [for (final minutes in [30, 60, 90, 120]) ChoiceChip(label: Text('$minutes'), selected: _duration == minutes, onSelected: _starting ? null : (_) => setState(() { _duration = minutes; _customDuration.clear(); }))]),
    TextButton(onPressed: _starting ? null : () => setState(() => _duration = null), child: const Text('Custom duration')),
    if (_duration == null) TextField(controller: _customDuration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutes (1–240)')),
    const SizedBox(height: 24), SizedBox(height: 56, child: FilledButton(onPressed: _starting || _courses.isEmpty ? null : _start, child: _starting ? const CircularProgressIndicator() : const Text('Start session'))),
  ])));
}
