import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../services/pdf_service.dart';
import '../services/queue_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import '../widgets/session_code_display.dart';

class MyAttendanceScreen extends StatelessWidget {
  const MyAttendanceScreen({super.key, required this.user});
  final AppUser user;
  @override
  Widget build(BuildContext context) {
    final queue = context.watch<QueueService>();
    if (!queue.ready) return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: const [SkeletonBox(width: 180, height: 30), SizedBox(height: 18), AppCard(child: SizedBox(height: 190, child: Center(child: SkeletonBox(width: 140, height: 140, radius: 80)))), AppCard(child: SkeletonList(count: 3)), AppCard(child: SkeletonList(count: 3))]));
    final marks = queue.historyFor(user.id).toList()..sort((a, b) => (DateTime.tryParse('${b['detectedAt']}') ?? DateTime(0)).compareTo(DateTime.tryParse('${a['detectedAt']}') ?? DateTime(0)));
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 28), children: [
      Text('My attendance', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      if (queue.lastSyncResult?.startsWith('Will retry') == true) AppCard(child: ErrorState(title: 'Marks will retry', message: queue.lastSyncResult!, onRetry: queue.syncNow)),
      AppCard(child: Column(children: [const _AttendanceRateRing(), const SizedBox(height: 12), Text('The server API does not provide a student history endpoint. Saved marks do not include absences or total sessions, so an overall attendance percentage cannot be calculated.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)])),
      const SizedBox(height: 14),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('This week', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6), Text('Local marks recorded by day', style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 12), SizedBox(height: 142, child: _WeeklyMarksChart(marks: marks))])),
      const SizedBox(height: 14),
      const SectionHeader('Per course'),
      const SizedBox(height: 4),
      const AppCard(child: EmptyState(icon: Icons.bar_chart_outlined, title: 'Course breakdown unavailable', message: 'Local marks do not contain a course ID, and the API contract has no student history endpoint.')),
      const SizedBox(height: 14),
      SectionHeader('Recent marks', subtitle: 'Newest first'),
      const SizedBox(height: 5),
      if (marks.isEmpty) const EmptyState(icon: Icons.event_available_outlined, title: 'No attendance yet. Mark your first session.', message: 'Your saved marks will appear here.') else ...marks.map((mark) => _AttendanceRecordTile(mark: mark, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ProofOfAttendanceScreen(mark: mark, user: user))))),
    ]);
  }
}

class ProofOfAttendanceScreen extends StatefulWidget {
  const ProofOfAttendanceScreen({super.key, required this.mark, required this.user});
  final Map<String, dynamic> mark;
  final AppUser user;
  @override
  State<ProofOfAttendanceScreen> createState() => _ProofOfAttendanceScreenState();
}
class _ProofOfAttendanceScreenState extends State<ProofOfAttendanceScreen> {
  bool _sharing = false;
  DateTime get _time => DateTime.tryParse('${widget.mark['detectedAt']}') ?? DateTime.now();
  String get _status => '${widget.mark['status'] ?? 'pending'}';
  String get _course => '${widget.mark['courseName'] ?? 'Unavailable in local mark data'}';
  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final bytes = await PdfService.proofOfAttendance(matricule: widget.user.matricule, fullName: widget.user.fullName, course: _course, detectedAt: _time, sessionCode: '${widget.mark['sessionCode'] ?? ''}', status: _status);
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: 'EZY-proof-${widget.mark['sessionCode'] ?? 'attendance'}.pdf', subject: 'EZY Proof of Attendance');
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share proof: $error'))); }
    finally { if (mounted) setState(() => _sharing = false); }
  }
  @override
  Widget build(BuildContext context) {
    final statusKind = switch (_status) { 'synced' => StatusKind.success, 'rejected' => StatusKind.error, _ => StatusKind.warning };
    return AppScaffold(appBar: AppBar(title: const Text('Proof of attendance')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Proof of attendance', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        SessionCodeDisplay(code: '${widget.mark['sessionCode'] ?? ''}'),
        const SizedBox(height: 12),
        InfoRow(label: 'Matricule', value: widget.user.matricule),
        InfoRow(label: 'Name', value: widget.user.fullName),
        InfoRow(label: 'Course', value: _course),
        InfoRow(label: 'Date and time', value: _time.toLocal().toString()),
        InfoRow(label: 'Session code', value: '${widget.mark['sessionCode'] ?? ''}'),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Text('Status', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const Spacer(), StatusPill(label: _status, kind: statusKind)])),
        if (_status == 'rejected' && widget.mark['reason'] != null) Text('${widget.mark['reason']}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ])),
      const SizedBox(height: 14),
      PrimaryButton(label: 'Share proof', loading: _sharing, icon: Icons.share_outlined, onPressed: _sharing ? null : _share),
    ])));
  }
}

class _AttendanceRecordTile extends StatelessWidget {
  const _AttendanceRecordTile({required this.mark, required this.onTap});
  final Map<String, dynamic> mark;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = '${mark['status'] ?? 'pending'}';
    final kind = switch (status) { 'synced' => StatusKind.success, 'rejected' => StatusKind.error, _ => StatusKind.warning };
    final time = DateTime.tryParse('${mark['detectedAt']}')?.toLocal();
    return AppCard(padding: EdgeInsets.zero, child: ListTile(onTap: onTap, leading: const Icon(Icons.verified_outlined), title: Text('${mark['courseName'] ?? 'Course unavailable'}'), subtitle: Text('${time ?? 'Time unavailable'}\nSession ${mark['sessionCode'] ?? ''}${status == 'rejected' ? '\n${mark['reason'] ?? 'Rejected'}' : ''}'), isThreeLine: true, trailing: StatusPill(label: status, kind: kind)));
  }
}

class _AttendanceRateRing extends StatelessWidget {
  const _AttendanceRateRing();
  @override
  Widget build(BuildContext context) => SizedBox(width: 174, height: 174, child: Stack(alignment: Alignment.center, children: [CustomPaint(size: const Size.square(174), painter: _RingPainter(Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.outline.withValues(alpha: .45))), Column(mainAxisSize: MainAxisSize.min, children: [Text('—', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppColors.darkPrimary)), Text('rate unavailable', style: Theme.of(context).textTheme.labelMedium)])]));
}
class _RingPainter extends CustomPainter {
  const _RingPainter(this.accent, this.track);
  final Color accent, track;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(9), 0, 6.283185307179586, false, paint..color = track);
  }
  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.accent != accent || oldDelegate.track != track;
}

class _WeeklyMarksChart extends StatelessWidget {
  const _WeeklyMarksChart({required this.marks});
  final List<Map<String, dynamic>> marks;
  @override
  Widget build(BuildContext context) {
    final counts = List<int>.filled(7, 0);
    final weekStart = DateTime.now().subtract(const Duration(days: 6));
    for (final mark in marks) {
      final date = DateTime.tryParse('${mark['detectedAt']}')?.toLocal();
      if (date == null || date.isBefore(DateTime(weekStart.year, weekStart.month, weekStart.day))) continue;
      counts[date.weekday - 1]++;
    }
    return CustomPaint(painter: _WeeklyMarksPainter(counts, Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.onSurfaceVariant), child: const SizedBox.expand());
  }
}
class _WeeklyMarksPainter extends CustomPainter {
  const _WeeklyMarksPainter(this.counts, this.accent, this.labelColor);
  final List<int> counts;
  final Color accent, labelColor;
  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 22.0;
    const top = 5.0;
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    final barWidth = size.width / 14;
    final slot = size.width / 7;
    final baseline = size.height - bottom;
    final guide = Paint()..color = labelColor.withValues(alpha: .2)..strokeWidth = 1;
    canvas.drawLine(Offset(0, baseline), Offset(size.width, baseline), guide);
    for (var i = 0; i < 7; i++) {
      final height = maxCount == 0 ? 4.0 : (size.height - top - bottom - 5) * counts[i] / maxCount;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(slot * i + (slot - barWidth) / 2, baseline - height, barWidth, height), const Radius.circular(6));
      canvas.drawRRect(rect, Paint()..color = counts[i] == 0 ? accent.withValues(alpha: .2) : accent);
      final text = TextPainter(text: TextSpan(text: _days[i], style: TextStyle(color: labelColor, fontSize: 11)), textDirection: TextDirection.ltr)..layout();
      text.paint(canvas, Offset(slot * i + (slot - text.width) / 2, baseline + 5));
    }
  }
  @override
  bool shouldRepaint(covariant _WeeklyMarksPainter oldDelegate) => oldDelegate.counts != counts || oldDelegate.accent != accent || oldDelegate.labelColor != labelColor;
}
