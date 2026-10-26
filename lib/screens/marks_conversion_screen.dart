import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../api/api_client.dart';
import '../models/app_user.dart';
import '../services/pdf_service.dart';
import '../services/session_service.dart';

class MarksConversionScreen extends StatefulWidget {
  const MarksConversionScreen({super.key, required this.course, required this.user});
  final Map<String, dynamic> course;
  final AppUser user;
  @override
  State<MarksConversionScreen> createState() => _MarksConversionScreenState();
}
class _MarksConversionScreenState extends State<MarksConversionScreen> {
  static const _options = [5, 10, 15, 20, 30];
  final _customController = TextEditingController();
  bool _loading = true, _custom = false, _exporting = false;
  int _maximum = 10, _requestVersion = 0;
  String? _error;
  int _totalSessions = 0;
  List<Map<String, dynamic>> _students = [];
  String get _courseId => '${widget.course['id'] ?? ''}';
  String get _courseCode => '${widget.course['code'] ?? ''}';
  String get _courseName => '${widget.course['name'] ?? ''}';

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final version = ++_requestVersion;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiClient(token: context.read<SessionService>().token).get('/api/courses/$_courseId/marks?max=$_maximum');
      if (result is! Map || result['students'] is! List) throw ApiException('The server returned an invalid marks report.');
      if (!mounted || version != _requestVersion) return;
      setState(() { _totalSessions = int.tryParse('${result['totalSessions']}') ?? 0; _students = (result['students'] as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList(); });
    } catch (error) { if (mounted && version == _requestVersion) setState(() => _error = error.toString()); }
    finally { if (mounted && version == _requestVersion) setState(() => _loading = false); }
  }

  void _chooseMaximum(int maximum) { setState(() { _maximum = maximum; _custom = false; }); _load(); }
  void _applyCustom() {
    final value = int.tryParse(_customController.text.trim());
    if (value == null || value < 1 || value > 100) { setState(() => _error = 'Enter a whole number from 1 to 100.'); return; }
    setState(() { _maximum = value; _custom = true; });
    _load();
  }

  String _display(Object? value) {
    if (value is num) return value % 1 == 0 ? value.toInt().toString() : value.toString();
    return '$value';
  }
  String get _departmentName => '${widget.course['departmentName'] ?? (widget.course['department'] is Map ? widget.course['department']['name'] : null) ?? widget.user.departmentName}';
  int get _year => int.tryParse('${widget.course['year'] ?? widget.user.year}') ?? widget.user.year;
  Future<List<int>> _buildPdf() => PdfService.marksSheet(courseCode: _courseCode, courseName: _courseName, departmentName: _departmentName, year: _year, maximum: _maximum, totalSessions: _totalSessions, students: _students);
  String get _filename => PdfService.marksFilename(_courseCode, DateTime.now());

  Future<void> _sharePdf() async {
    setState(() => _exporting = true);
    try { await Printing.sharePdf(bytes: Uint8List.fromList(await _buildPdf()), filename: _filename, subject: 'EZY Attendance Marks Sheet'); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share the PDF: $error'))); }
    finally { if (mounted) setState(() => _exporting = false); }
  }
  Future<void> _savePdf() async {
    setState(() => _exporting = true);
    try { final bytes = await _buildPdf(); await Printing.layoutPdf(name: _filename, onLayout: (_) async => Uint8List.fromList(bytes)); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open the save/print dialog: $error'))); }
    finally { if (mounted) setState(() => _exporting = false); }
  }
  @override
  void dispose() { _requestVersion++; _customController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Convert to marks')), body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
    Text('$_courseCode — $_courseName', style: Theme.of(context).textTheme.titleLarge),
    Text('$_departmentName — Year $_year'),
    const SizedBox(height: 12), Text('Maximum marks', style: Theme.of(context).textTheme.titleMedium),
    Wrap(spacing: 8, children: [for (final value in _options) ChoiceChip(label: Text('$value'), selected: !_custom && _maximum == value, onSelected: (_) => _chooseMaximum(value))]),
    TextButton(onPressed: () => setState(() => _custom = true), child: const Text('Custom maximum')),
    if (_custom) Row(children: [Expanded(child: TextField(controller: _customController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maximum (1–100)'), onSubmitted: (_) => _applyCustom())), const SizedBox(width: 8), FilledButton(onPressed: _applyCustom, child: const Text('Apply'))]),
    const SizedBox(height: 12),
    if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
    else if (_error != null) ...[Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), OutlinedButton(onPressed: _load, child: const Text('Retry'))]
    else ...[
      Text('Maximum: $_maximum    Total sessions held: $_totalSessions', style: Theme.of(context).textTheme.titleMedium),
      if (_totalSessions == 0) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No sessions held yet.')),
      if (_students.isEmpty) const Text('No students in this class yet.') else SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('Matricule')), DataColumn(label: Text('Name')), DataColumn(label: Text('Attended/Total')), DataColumn(label: Text('%')), DataColumn(label: Text('Marks'))], rows: [for (final student in _students) DataRow(cells: [DataCell(Text('${student['matricule'] ?? ''}')), DataCell(Text('${student['fullName'] ?? ''}')), DataCell(Text('${student['attended'] ?? 0}/$_totalSessions')), DataCell(Text('${_display(student['percentage'] ?? 0)}%')), DataCell(Text('${_display(student['marks'] ?? 0)} / $_maximum'))])])),
      const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: [FilledButton.icon(onPressed: _exporting ? null : _sharePdf, icon: const Icon(Icons.share), label: const Text('Share PDF')), OutlinedButton.icon(onPressed: _exporting ? null : _savePdf, icon: const Icon(Icons.save_alt), label: const Text('Save PDF'))]),
      if (_exporting) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
    ],
  ])));
}
