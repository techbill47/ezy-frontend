import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../services/session_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
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
    try {
      final data = await ApiClient(token: context.read<SessionService>().token).get('/api/courses');
      if (data is! List) throw ApiException('The server returned an invalid course list.');
      if (mounted) setState(() { _courses = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); _courseId ??= _courses.isEmpty ? null : '${_courses.first['id']}'; });
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _start() async {
    final sessionService = context.read<SessionService>();
    final duration = _duration ?? int.tryParse(_customDuration.text.trim());
    if (_courseId == null) { setState(() => _error = 'Choose a course.'); return; }
    if (duration == null || duration < 1 || duration > 240) { setState(() => _error = 'Duration must be a whole number from 1 to 240 minutes.'); return; }
    await NotificationService.instance.requestPermission(context);
    if (!mounted) return;
    setState(() { _starting = true; _error = null; _notice = null; });
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
      final endsAt = DateTime.tryParse('${session['endsAt'] ?? ''}');
      if (endsAt != null) await NotificationService.instance.scheduleSessionReminder(sessionId: '${session['id'] ?? ''}', endsAt: endsAt, session: session, course: selected);
      if (!mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => LiveSessionScreen(session: session, course: selected, user: user!, resumed: session['_activeSession'] == true)));
      if (mounted) setState(() => _notice = 'The live session screen was closed, so its BLE broadcast stopped. Tap Start session to resume an active session.');
    } catch (error) {
      if (mounted) setState(() => _error = error is ApiException && error.statusCode == null ? 'Cannot start a session without internet. The coordinator needs internet only to start the session. ${error.message}' : error.toString());
    } finally { if (mounted) setState(() => _starting = false); }
  }

  @override
  void dispose() { _customDuration.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Start session')),
    body: SafeArea(child: _loading ? const LoadingView(message: 'Loading your courses…') : _error != null && _courses.isEmpty ? ErrorState(message: _error!, onRetry: _loadCourses, title: 'Courses unavailable') : RefreshIndicator(onRefresh: _loadCourses, child: ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 28), children: [
      Text('Set up your class', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6), Text('Choose a course and session length.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      if (_notice != null) ...[const SizedBox(height: 14), StatusPill(label: _notice!, kind: StatusKind.info)],
      if (_error != null) ...[const SizedBox(height: 14), _ErrorBanner(message: _error!)],
      const SizedBox(height: 24),
      SectionHeader('Course'),
      const SizedBox(height: 9),
      if (_courses.isEmpty) const EmptyState(icon: Icons.menu_book_outlined, title: 'No courses yet', message: 'Add a course before starting a session.') else DropdownButtonFormField<String>(isExpanded: true, initialValue: _courseId, decoration: const InputDecoration(labelText: 'Choose course'), items: _courses.map((course) => DropdownMenuItem(value: '${course['id']}', child: Text('${course['code']} — ${course['name']}', overflow: TextOverflow.ellipsis))).toList(), onChanged: _starting ? null : (value) => setState(() => _courseId = value)),
      const SizedBox(height: 25),
      SectionHeader('Duration', subtitle: 'Minutes'),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final minutes in [30, 60, 90, 120]) ChoiceChip(label: Text('$minutes min'), selected: _duration == minutes, onSelected: _starting ? null : (_) => setState(() { _duration = minutes; _customDuration.clear(); }))]),
      const SizedBox(height: 12),
      if (_duration == null) TextField(controller: _customDuration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Custom duration', suffixText: 'minutes', hintText: '1–240')) else TextButton(onPressed: _starting ? null : () => setState(() => _duration = null), child: const Text('Enter a custom duration')),
      const SizedBox(height: 28),
      PrimaryButton(label: 'Start session', icon: Icons.sensors, loading: _starting, onPressed: _starting || _courses.isEmpty ? null : _start),
    ]))),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer), const SizedBox(width: 10), Expanded(child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)))]));
}
