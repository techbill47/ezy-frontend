import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../api/api_client.dart';
import '../models/app_user.dart';
import '../services/pdf_service.dart';
import '../services/session_service.dart';
import 'pdf_preview_screen.dart';

class SessionReportScreen extends StatefulWidget {
  const SessionReportScreen({super.key, required this.session, required this.user});
  final Map<String, dynamic> session;
  final AppUser user;
  @override
  State<SessionReportScreen> createState() => _SessionReportScreenState();
}
class _SessionReportScreenState extends State<SessionReportScreen> {
  bool _loading = true, _exporting = false;
  String? _error;
  Map<String, dynamic> _course = {}, _session = {};
  List<Map<String, dynamic>> _students = [];
  String get _id => '${widget.session['id'] ?? ''}';
  DateTime get _sessionDate => DateTime.tryParse('${_session['startedAt'] ?? widget.session['startedAt']}') ?? DateTime.now();
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiClient(token: context.read<SessionService>().token).get('/api/sessions/$_id/report');
      if (result is! Map || result['students'] is! List) throw ApiException('The server returned an invalid attendance report.');
      final course = result['course'] is Map ? Map<String, dynamic>.from(result['course']) : <String, dynamic>{};
      final session = result['session'] is Map ? Map<String, dynamic>.from(result['session']) : Map<String, dynamic>.from(widget.session);
      final students = (result['students'] as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()..sort((a, b) { final p = (b['present'] == true ? 1 : 0).compareTo(a['present'] == true ? 1 : 0); return p != 0 ? p : '${a['matricule'] ?? ''}'.compareTo('${b['matricule'] ?? ''}'); });
      if (mounted) setState(() { _course = course; _session = session; _students = students; });
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<List<int>> _buildPdf() => PdfService.attendanceSheet(courseCode: '${_course['code'] ?? widget.session['courseCode'] ?? ''}', courseName: '${_course['name'] ?? widget.session['courseName'] ?? ''}', departmentName: '${_course['departmentName'] ?? (_course['department'] is Map ? _course['department']['name'] : null) ?? widget.user.departmentName}', year: int.tryParse('${_course['year'] ?? widget.user.year}') ?? widget.user.year, sessionDate: _sessionDate, students: _students);
  String get _filename => PdfService.attendanceFilename('${_course['code'] ?? widget.session['courseCode'] ?? 'session'}', _sessionDate);
  Future<void> _share() async {
    setState(() => _exporting = true);
    try { await Printing.sharePdf(bytes: Uint8List.fromList(await _buildPdf()), filename: _filename, subject: 'EZY Attendance Sheet'); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share the PDF: $error'))); }
    finally { if (mounted) setState(() => _exporting = false); }
  }
  Future<void> _save() async {
    setState(() => _exporting = true);
    try { final bytes = await _buildPdf(); await Printing.layoutPdf(name: _filename, onLayout: (_) async => Uint8List.fromList(bytes)); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open the save/print dialog: $error'))); }
    finally { if (mounted) setState(() => _exporting = false); }
  }
  void _preview() => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PdfPreviewScreen(title: 'Attendance PDF preview', buildPdf: _buildPdf)));
  @override
  Widget build(BuildContext context) {
    final present = _students.where((s) => s['present'] == true).length;
    final absent = _students.length - present;
    return Scaffold(appBar: AppBar(title: const Text('Attendance report'), actions: [IconButton(onPressed: _load, tooltip: 'Refresh report', icon: const Icon(Icons.refresh))]), body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Retry'))]))) : ListView(padding: const EdgeInsets.all(16), children: [
      Text('${_course['code'] ?? widget.session['courseCode'] ?? ''} — ${_course['name'] ?? widget.session['courseName'] ?? ''}', style: Theme.of(context).textTheme.titleLarge),
      Text('${_course['departmentName'] ?? widget.user.departmentName} — Year ${_course['year'] ?? widget.user.year}'),
      Text('Session: ${_sessionDate.toLocal()}'),
      Text('Present: $present    Absent: $absent    Total: ${_students.length}'),
      const SizedBox(height: 12),
      if (_students.isEmpty) const Text('No students are listed in this report.') else ..._students.map((s) => ListTile(title: Text('${s['fullName'] ?? ''}'), subtitle: Text('${s['matricule'] ?? ''}'), trailing: Text(s['present'] == true ? 'Present' : 'Absent'))),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [FilledButton.icon(onPressed: _exporting ? null : _share, icon: const Icon(Icons.share), label: const Text('Share PDF')), OutlinedButton.icon(onPressed: _exporting ? null : _save, icon: const Icon(Icons.save_alt), label: const Text('Save PDF')), OutlinedButton.icon(onPressed: _preview, icon: const Icon(Icons.preview), label: const Text('Preview'))]),
      if (_exporting) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
    ]));
  }
}
