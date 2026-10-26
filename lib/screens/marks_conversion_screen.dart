import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../api/api_client.dart';
import '../models/app_user.dart';
import '../services/pdf_service.dart';
import '../services/session_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/offline_banner.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';

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
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Convert to marks')),
    body: Column(children: [
      const OfflineBanner(role: 'coordinator'),
      Expanded(child: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_courseCode — $_courseName', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('$_departmentName  •  Year $_year', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          const SectionHeader('Maximum marks'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final value in _options) ChoiceChip(label: Text('$value'), selected: !_custom && _maximum == value, onSelected: (_) => _chooseMaximum(value))]),
          const SizedBox(height: 8),
          if (_custom) Row(children: [Expanded(child: TextField(controller: _customController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Custom maximum', hintText: 'Enter 1 to 100', suffixText: '/ 100'), onSubmitted: (_) => _applyCustom())), const SizedBox(width: 9), PrimaryButton(label: 'Apply', onPressed: _applyCustom)]) else TextButton(onPressed: () => setState(() => _custom = true), child: const Text('Choose a custom maximum')),
        ])),
        const SizedBox(height: 8),
        if (_loading) const AppCard(child: SkeletonList(count: 6))
        else if (_error != null) ErrorState(title: 'Marks unavailable', message: _error!, onRetry: _load)
        else ...[
          AppCard(child: Row(children: [Expanded(child: InfoRow(label: 'Maximum', value: '$_maximum marks')), Expanded(child: InfoRow(label: 'Sessions held', value: '$_totalSessions'))])),
          if (_totalSessions == 0) const AppCard(child: EmptyState(icon: Icons.event_busy_outlined, title: 'No sessions held yet', message: 'Marks will be available after this course has held a session.'))
          else if (_students.isEmpty) const AppCard(child: EmptyState(icon: Icons.people_outline, title: 'No students found', message: 'There are no students listed for this course.'))
          else AppCard(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader('Student marks', subtitle: 'Scroll the table to view all columns and students'),
            const SizedBox(height: 10),
            SizedBox(height: 430, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: 652, child: CustomScrollView(slivers: [
              SliverPersistentHeader(pinned: true, delegate: _MarksHeaderDelegate(Theme.of(context).colorScheme)),
              SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                final student = _students[index];
                return _MarksRow(index: index, matricule: '${student['matricule'] ?? ''}', name: '${student['fullName'] ?? ''}', attendance: '${student['attended'] ?? 0}/$_totalSessions', percent: '${_display(student['percentage'] ?? 0)}%', marks: '${_display(student['marks'] ?? 0)} / $_maximum');
              }, childCount: _students.length)),
            ])))),
          ])),
          const SizedBox(height: 14),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader('Export marks sheet', subtitle: 'Create a PDF to share or save'),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Share PDF', icon: Icons.share_outlined, loading: _exporting, onPressed: _exporting ? null : _sharePdf),
            const SizedBox(height: 8), SecondaryButton(label: 'Save PDF', icon: Icons.save_alt, onPressed: _exporting ? null : _savePdf),
          ])),
        ],
      ]))),
    ]),
  );
}

class _MarksHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MarksHeaderDelegate(this.scheme);
  final ColorScheme scheme;
  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: scheme.surfaceContainerHighest, child: Row(children: [
    _tableCell('No.', 44, header: true), _tableCell('Matricule', 112, header: true), _tableCell('Full name', 164, header: true), _tableCell('Attended / total', 112, header: true), _tableCell('%', 76, header: true), _tableCell('Marks', 110, header: true, color: scheme.primary),
  ]));
  @override
  bool shouldRebuild(covariant _MarksHeaderDelegate oldDelegate) => oldDelegate.scheme != scheme;
}

class _MarksRow extends StatelessWidget {
  const _MarksRow({required this.index, required this.matricule, required this.name, required this.attendance, required this.percent, required this.marks});
  final int index;
  final String matricule, name, attendance, percent, marks;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(height: 56, decoration: BoxDecoration(color: index.isEven ? scheme.surface : scheme.surfaceContainerHighest.withValues(alpha: .4), border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)))), child: Row(children: [
      _tableCell('${index + 1}', 44), _tableCell(matricule, 112), _tableCell(name, 164), _tableCell(attendance, 112), _tableCell(percent, 76), _tableCell(marks, 110, color: scheme.primary),
    ]));
  }
}

Widget _tableCell(String value, double width, {bool header = false, Color? color}) => SizedBox(width: width, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: header ? 11 : 12, fontWeight: header || color != null ? FontWeight.w700 : FontWeight.w500, color: color))));
