import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../api/api_client.dart';
import '../models/app_user.dart';
import '../services/pdf_service.dart';
import '../services/session_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
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
      final students = (result['students'] as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()..sort((a, b) {
        final p = (b['present'] == true ? 1 : 0).compareTo(a['present'] == true ? 1 : 0);
        return p != 0 ? p : '${a['matricule'] ?? ''}'.compareTo('${b['matricule'] ?? ''}');
      });
      if (mounted) setState(() { _course = course; _session = session; _students = students; });
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<List<int>> _buildPdf() => PdfService.attendanceSheet(
    courseCode: '${_course['code'] ?? widget.session['courseCode'] ?? ''}',
    courseName: '${_course['name'] ?? widget.session['courseName'] ?? ''}',
    departmentName: '${_course['departmentName'] ?? (_course['department'] is Map ? _course['department']['name'] : null) ?? widget.user.departmentName}',
    year: int.tryParse('${_course['year'] ?? widget.user.year}') ?? widget.user.year,
    sessionDate: _sessionDate,
    students: _students,
  );
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
    final present = _students.where((student) => student['present'] == true).length;
    final absent = _students.length - present;
    final title = '${_course['code'] ?? widget.session['courseCode'] ?? ''} — ${_course['name'] ?? widget.session['courseName'] ?? ''}';
    return AppScaffold(
      appBar: AppBar(title: const Text('Session detail'), actions: [IconButton(onPressed: _load, tooltip: 'Refresh report', icon: const Icon(Icons.refresh))]),
      body: _loading ? ListView(padding: const EdgeInsets.all(16), children: const [AppCard(child: SkeletonList(count: 2)), SizedBox(height: 18), SkeletonList(count: 7)]) : _error != null
        ? ErrorState(title: 'Report unavailable', message: _error!, onRetry: _load)
        : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${_course['departmentName'] ?? widget.user.departmentName}  •  Year ${_course['year'] ?? widget.user.year}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              InfoRow(label: 'Session date', value: DateFormat('EEE, d MMM yyyy').format(_sessionDate.toLocal()), icon: Icons.calendar_today_outlined),
              InfoRow(label: 'Start time', value: DateFormat('h:mm a').format(_sessionDate.toLocal()), icon: Icons.schedule),
              const Divider(height: 22),
              Row(children: [Expanded(child: _SummaryNumber(label: 'Present', value: present.toString(), icon: Icons.check_circle_outline)), Expanded(child: _SummaryNumber(label: 'Absent', value: absent.toString(), icon: Icons.cancel_outlined)), Expanded(child: _SummaryNumber(label: 'Total', value: _students.length.toString(), icon: Icons.people_outline))]),
            ])),
            const SizedBox(height: 8),
            const SectionHeader('Attendance list', subtitle: 'Present students first'),
            const SizedBox(height: 8),
            if (_students.isEmpty) const EmptyState(icon: Icons.people_outline, title: 'No students in this report', message: 'There are no students to show for this class.') else ..._students.map((student) => AppCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Row(children: [
              CircleAvatar(radius: 20, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .12), foregroundColor: Theme.of(context).colorScheme.primary, child: Text('${student['fullName'] ?? '?'}'.trim().isEmpty ? '?' : '${student['fullName']}'.trim()[0].toUpperCase())),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${student['fullName'] ?? ''}', style: Theme.of(context).textTheme.titleSmall), Text('${student['matricule'] ?? ''}', style: Theme.of(context).textTheme.bodySmall)])),
              StatusPill(label: student['present'] == true ? 'Present' : 'Absent', kind: student['present'] == true ? StatusKind.success : StatusKind.neutral),
            ]))),
            const SizedBox(height: 18),
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionHeader('Export attendance PDF', subtitle: 'Share, save, or preview this session sheet'),
              const SizedBox(height: 14),
              PrimaryButton(label: 'Export PDF', icon: Icons.share_outlined, loading: _exporting, onPressed: _exporting ? null : _share),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: SecondaryButton(label: 'Save', icon: Icons.save_alt, onPressed: _exporting ? null : _save)), const SizedBox(width: 8), Expanded(child: SecondaryButton(label: 'Preview', icon: Icons.preview_outlined, onPressed: _preview))]),
            ])),
          ])),
    );
  }
}

class _SummaryNumber extends StatelessWidget {
  const _SummaryNumber({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(children: [Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 4), Text(value, style: Theme.of(context).textTheme.titleLarge), Text(label, style: Theme.of(context).textTheme.bodySmall)]);
}
