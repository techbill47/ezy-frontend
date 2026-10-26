import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../services/session_service.dart';
import 'marks_conversion_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});
  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true, _saving = false;
  String? _error;
  final _code = TextEditingController(), _name = TextEditingController();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiClient(token: context.read<SessionService>().token).get('/api/courses');
      if (result is! List) throw ApiException('The server returned an invalid course list.');
      if (mounted) setState(() => _courses = result.whereType<Map>().map((c) => Map<String, dynamic>.from(c)).toList());
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _addCourse() async {
    final code = _code.text.trim(), name = _name.text.trim();
    if (code.isEmpty || name.isEmpty) { setState(() => _error = 'Enter both a course code and name.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await ApiClient(token: context.read<SessionService>().token).post('/api/courses', {'code': code, 'name': name});
      _code.clear(); _name.clear();
      if (mounted) Navigator.pop(context);
      await _load();
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _showAddForm() async {
    _error = null;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, refresh) => AlertDialog(title: const Text('Add course'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Course code')), TextField(controller: _name, decoration: const InputDecoration(labelText: 'Course name')), if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))), if (_saving) const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())]), actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: _saving ? null : () async { await _addCourse(); refresh(() {}); }, child: const Text('Add'))])));
  }

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _code.dispose(); _name.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isCoordinator = context.watch<SessionService>().user?.role == 'coordinator';
    return Scaffold(appBar: AppBar(title: const Text('Courses')), floatingActionButton: isCoordinator ? FloatingActionButton.extended(onPressed: _saving ? null : _showAddForm, icon: const Icon(Icons.add), label: const Text('Add course')) : null,
      body: RefreshIndicator(onRefresh: _load, child: _loading ? ListView(children: const [SizedBox(height: 250), Center(child: CircularProgressIndicator())]) : _error != null ? ListView(padding: const EdgeInsets.all(24), children: [Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 12), OutlinedButton(onPressed: _load, child: const Text('Retry'))]) : _courses.isEmpty ? ListView(children: const [SizedBox(height: 180), Center(child: Text('No courses yet.'))]) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _courses.length, separatorBuilder: (_, _) => const Divider(), itemBuilder: (context, i) { final course = _courses[i]; return ListTile(title: Text('${course['code'] ?? ''}'), subtitle: Text('${course['name'] ?? ''}'), trailing: isCoordinator ? TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MarksConversionScreen(course: course, user: context.read<SessionService>().user!))), child: const Text('Convert to marks')) : null); })),
    );
  }
}
