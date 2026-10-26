import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/app_user.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/surfaces.dart';
import 'ble_test_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startAtRegistration = false});
  final bool startAtRegistration;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _matricule = TextEditingController(), _name = TextEditingController(), _phone = TextEditingController(), _pin = TextEditingController(), _coordinatorCode = TextEditingController();
  bool _register = false, _loading = false, _showPin = false;
  String _role = 'student';
  int _year = 1;
  int? _departmentId;
  List<Map<String, dynamic>> _departments = [];
  String? _error;

  @override
  void initState() { super.initState(); _register = widget.startAtRegistration; _loadDepartments(); }
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
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _openBleTest() => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const BleTestScreen()));
  @override
  void dispose() { _matricule.dispose(); _name.dispose(); _phone.dispose(); _pin.dispose(); _coordinatorCode.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: GestureDetector(behavior: HitTestBehavior.opaque, onLongPress: _register ? null : _openBleTest, child: Text(_register ? 'Create account' : 'Sign in'))),
    body: SafeArea(child: Form(key: _form, child: ListView(padding: const EdgeInsets.fromLTRB(24, 10, 24, 28), children: [
      Center(child: Text('EZY', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.darkPrimary, letterSpacing: 2.5))),
      const SizedBox(height: 4),
      Center(child: Text(_register ? 'Create your attendance account' : 'Smart Bluetooth Attendance', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center)),
      const SizedBox(height: 24),
      AppTextField(controller: _matricule, textCapitalization: TextCapitalization.characters, label: 'Matricule', hint: 'Enter your matricule', prefixIcon: Icons.badge_outlined, validator: _required),
      if (_register) ...[
        const SizedBox(height: 14),
        AppTextField(controller: _name, label: 'Full name', hint: 'As shown in school records', prefixIcon: Icons.person_outline, validator: _required),
        const SizedBox(height: 14),
        AppTextField(controller: _phone, label: 'Phone', keyboardType: TextInputType.phone, prefixIcon: Icons.phone_outlined, validator: _required),
        const SizedBox(height: 18),
        DropdownButtonFormField<int>(isExpanded: true, initialValue: _departmentId, decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.account_balance_outlined)), items: _departments.map((d) => DropdownMenuItem(value: int.tryParse('${d['id']}'), child: Text('${d['name']}', overflow: TextOverflow.ellipsis))).toList(), onChanged: _loading ? null : (v) => setState(() => _departmentId = v), validator: (v) => v == null ? 'Choose a department.' : null),
        const SizedBox(height: 18),
        Text('Year of study', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 7),
        Wrap(spacing: 8, children: [for (var year = 1; year <= 5; year++) ChoiceChip(label: Text('$year'), selected: _year == year, onSelected: _loading ? null : (_) => setState(() => _year = year))]),
        const SizedBox(height: 18),
        Text('Account type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: _roleCard('student', 'Student', Icons.school_outlined)), const SizedBox(width: 12), Expanded(child: _roleCard('coordinator', 'Coordinator', Icons.groups_2_outlined))]),
        if (_role == 'coordinator') ...[
          const SizedBox(height: 14),
          AppTextField(controller: _coordinatorCode, label: 'Coordinator code', hint: 'Given by the school admin', prefixIcon: Icons.key_outlined, validator: _required),
          const SizedBox(height: 5),
          Text('Ask your school admin for this code.', style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 14),
      ] else const SizedBox(height: 18),
      AppTextField(controller: _pin, label: '4-digit PIN', hint: 'Enter your PIN', obscureText: !_showPin, keyboardType: TextInputType.number, maxLength: 4, prefixIcon: Icons.lock_outline, suffixIcon: IconButton(tooltip: _showPin ? 'Hide PIN' : 'Show PIN', onPressed: () => setState(() => _showPin = !_showPin), icon: Icon(_showPin ? Icons.visibility_off_outlined : Icons.visibility_outlined)), validator: _pinValidation),
      const SizedBox(height: 8),
      SizedBox(height: 68, child: _error == null ? const SizedBox.shrink() : Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: .4))), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer), const SizedBox(width: 10), Expanded(child: Text(_error!, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer)))]))),
      PrimaryButton(label: _register ? 'Create account' : 'Sign in', loading: _loading, onPressed: _loading ? null : _submit),
      const SizedBox(height: 8),
      TextButton(onPressed: _loading ? null : () => setState(() { _register = !_register; _error = null; }), child: Text(_register ? 'Already have an account? Sign in' : 'New to EZY? Create an account')),
    ]))),
  );

  Widget _roleCard(String role, String label, IconData icon) {
    final selected = _role == role;
    final scheme = Theme.of(context).colorScheme;
    return Material(color: Colors.transparent, child: InkWell(onTap: _loading ? null : () => setState(() { _role = role; _error = null; }), borderRadius: BorderRadius.circular(16), child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 92), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: selected ? scheme.primary.withValues(alpha: .12) : scheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? scheme.primary : scheme.outline, width: selected ? 1.7 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant), const SizedBox(height: 7), Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: selected ? scheme.primary : scheme.onSurface))])))));
  }
}
