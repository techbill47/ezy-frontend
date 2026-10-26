import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/app_user.dart';
import '../services/session_service.dart';
import 'design_preview_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _matricule = TextEditingController(), _name = TextEditingController(), _phone = TextEditingController(), _pin = TextEditingController(), _coordinatorCode = TextEditingController();
  bool _register = false, _loading = false;
  String _role = 'student';
  int _year = 1;
  int? _departmentId;
  List<Map<String, dynamic>> _departments = [];
  String? _error;

  @override
  void initState() { super.initState(); _loadDepartments(); }
  Future<void> _loadDepartments() async {
    try {
      final data = await ApiClient().get('/api/departments');
      if (data is List && mounted) setState(() { _departments = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); });
    } catch (_) { /* Login remains available if the department list cannot load. */ }
  }
  String? _required(String? value) => value == null || value.trim().isEmpty ? 'This field is required.' : null;
  String? _pinValidation(String? value) => value == null || !RegExp(r'^\d{4}$').hasMatch(value) ? 'Enter exactly 4 digits.' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_register && (_departmentId == null || _departments.isEmpty)) { setState(() => _error = 'Departments are unavailable. Check your connection and try again.'); return; }
    setState(() { _loading = true; _error = null; });
    final session = context.read<SessionService>();
    try {
      final body = <String, dynamic>{'matricule': _matricule.text, 'pin': _pin.text};
      if (_register) {
        body.addAll({'fullName': _name.text.trim(), 'phone': _phone.text.trim(), 'departmentId': _departmentId, 'year': _year, 'role': _role});
        if (_role == 'coordinator') body['coordinatorCode'] = _coordinatorCode.text.trim();
      }
      final result = await ApiClient().post(_register ? '/api/auth/register' : '/api/auth/login', body) as Map<String, dynamic>;
      await session.save(result['token'] as String, AppUser.fromJson(Map<String, dynamic>.from(result['user'] as Map)));
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  void dispose() { _matricule.dispose(); _name.dispose(); _phone.dispose(); _pin.dispose(); _coordinatorCode.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: GestureDetector(behavior: HitTestBehavior.opaque, onLongPress: _register ? null : () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DesignPreviewScreen())), child: Text(_register ? 'Create account' : 'EZY sign in'))), body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(24), children: [
    TextFormField(controller: _matricule, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Matricule'), validator: _required),
    if (_register) ...[
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name'), validator: _required),
      TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'), validator: _required),
      DropdownButtonFormField<int>(isExpanded: true, decoration: const InputDecoration(labelText: 'Department'), initialValue: _departmentId, items: _departments.map((d) => DropdownMenuItem(value: int.tryParse('${d['id']}'), child: Text('${d['name']}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => _departmentId = v), validator: (v) => v == null ? 'Choose a department.' : null),
      DropdownButtonFormField<int>(decoration: const InputDecoration(labelText: 'Year'), initialValue: _year, items: [for (var i = 1; i <= 5; i++) DropdownMenuItem(value: i, child: Text('$i'))], onChanged: (v) => setState(() => _year = v ?? 1)),
      DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Role'), initialValue: _role, items: const [DropdownMenuItem(value: 'student', child: Text('Student')), DropdownMenuItem(value: 'coordinator', child: Text('Coordinator'))], onChanged: (v) => setState(() => _role = v ?? 'student')),
      if (_role == 'coordinator') TextFormField(controller: _coordinatorCode, decoration: const InputDecoration(labelText: 'Coordinator code'), validator: _required),
    ],
    TextFormField(controller: _pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: '4-digit PIN', counterText: ''), validator: _pinValidation),
    if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    const SizedBox(height: 16),
    SizedBox(height: 56, child: FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const CircularProgressIndicator() : Text(_register ? 'Register' : 'Log in'))),
    TextButton(onPressed: _loading ? null : () => setState(() { _register = !_register; _error = null; }), child: Text(_register ? 'Already have an account? Log in' : 'Create an account')),
  ])));
}
