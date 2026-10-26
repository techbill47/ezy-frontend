import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../api/api_client.dart';
import '../models/app_user.dart';
import '../services/ble_service.dart';
import '../services/session_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/session_code_display.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'session_report_screen.dart';

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({super.key, required this.session, required this.course, required this.user, required this.resumed});
  final Map<String, dynamic> session, course;
  final AppUser user;
  final bool resumed;
  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final BleService _ble = BleService();
  Timer? _clock, _refreshTimer, _feedTimer;
  List<Map<String, dynamic>> _students = [];
  final List<_Arrival> _feed = [];
  final Set<String> _presentIds = {};
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
  late final AnimationController _takeoverAnimation = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
  DateTime? _endsAt;
  String? _reportError, _broadcastError, _notice;
  bool _broadcasting = false, _broadcastBusy = false, _ending = false, _ended = false, _reportLoading = false, _reportLoaded = false, _paused = false, _takeover = false, _listExpanded = false;
  String get _id => '${widget.session['id'] ?? ''}';
  String get _code => '${widget.session['code'] ?? ''}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final raw = widget.session['endsAt'] ?? (widget.session['session'] is Map ? widget.session['session']['endsAt'] : null);
    _endsAt = DateTime.tryParse('$raw');
    _ended = '${widget.session['status'] ?? ''}' == 'ended' || (_endsAt != null && !_endsAt!.isAfter(DateTime.now()));
    WakelockPlus.enable();
    if (widget.resumed) _notice = 'An active session already existed. This session has resumed.';
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadReport());
    _feedTimer = Timer.periodic(const Duration(seconds: 1), (_) => _expireFeed());
    _loadReport();
    if (!_ended) startBroadcast();
  }

  void _expireFeed() {
    final now = DateTime.now();
    final kept = _feed.where((entry) => now.difference(entry.addedAt) < const Duration(seconds: 8)).toList();
    if (kept.length != _feed.length && mounted) setState(() { _feed..clear()..addAll(kept); });
  }

  void _tick() {
    if (_endsAt != null && !_ended && !_endsAt!.isAfter(DateTime.now())) {
      setState(() { _ended = true; _broadcasting = false; _notice = 'Session time is over. Advertising stopped.'; });
      _ble.stopAdvertising();
      WakelockPlus.disable();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> startBroadcast() async {
    if (_broadcastBusy || _ended) return;
    setState(() { _broadcastBusy = true; _broadcastError = null; });
    try {
      await _ble.startAdvertising(context, widget.user.departmentId, widget.user.year, _code);
      if (!mounted) return;
      setState(() { _broadcasting = true; _paused = false; _broadcastError = null; _takeover = true; });
      await _takeoverAnimation.forward(from: 0);
      if (mounted) setState(() => _takeover = false);
    } catch (error) {
      if (mounted) setState(() { _broadcasting = false; _broadcastError = error.toString(); _takeover = false; });
    } finally { if (mounted) setState(() => _broadcastBusy = false); }
  }

  Future<void> _loadReport() async {
    if (_reportLoading) return;
    if (!mounted) return;
    setState(() => _reportLoading = true);
    try {
      final report = await ApiClient(token: context.read<SessionService>().token).get('/api/sessions/$_id/report');
      if (report is! Map || report['students'] is! List) throw ApiException('The server returned an invalid attendance report.');
      final people = (report['students'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()..sort((a, b) {
        final present = (b['present'] == true ? 1 : 0).compareTo(a['present'] == true ? 1 : 0);
        return present != 0 ? present : '${a['fullName'] ?? ''}'.compareTo('${b['fullName'] ?? ''}');
      });
      if (!mounted) return;
      final nextPresent = people.where((p) => p['present'] == true).map((p) => '${p['matricule'] ?? ''}').where((id) => id.isNotEmpty).toSet();
      if (_reportLoaded) {
        final now = DateTime.now();
        for (final person in people.where((p) => p['present'] == true)) {
          final id = '${person['matricule'] ?? ''}';
          if (id.isNotEmpty && !_presentIds.contains(id)) {
            _feed.insert(0, _Arrival(name: '${person['fullName'] ?? 'Student'}', id: id, addedAt: now));
          }
        }
        if (_feed.length > 5) _feed.removeRange(5, _feed.length);
      }
      setState(() { _students = people; _presentIds..clear()..addAll(nextPresent); _reportError = null; _reportLoaded = true; });
    } catch (error) {
      if (mounted) setState(() => _reportError = 'Attendance list could not refresh: $error');
    } finally { if (mounted) setState(() => _reportLoading = false); }
  }

  Future<void> _endSession() async {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('End session?'), content: const Text('Students will no longer be able to mark attendance for this session.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep session')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('End session'))]));
    if (accepted != true || !mounted) return;
    setState(() { _ending = true; _reportError = null; });
    try {
      await ApiClient(token: context.read<SessionService>().token).post('/api/sessions/$_id/end');
      await _ble.stopAdvertising();
      await WakelockPlus.disable();
      if (mounted) setState(() { _ended = true; _broadcasting = false; _notice = 'Session ended.'; });
      await _loadReport();
    } catch (error) { if (mounted) setState(() => _reportError = 'Could not end the session: $error'); }
    finally { if (mounted) setState(() => _ending = false); }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      if (_broadcasting) { _ble.stopAdvertising(); if (mounted) setState(() { _broadcasting = false; _paused = true; }); }
      WakelockPlus.disable();
    } else if (state == AppLifecycleState.resumed && mounted) {
      WakelockPlus.enable();
      if (_paused) setState(() { _notice = 'Broadcast stopped while you were away. Tap Retry to broadcast again.'; _broadcastError = 'Broadcast stopped while the app was away.'; });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel(); _refreshTimer?.cancel(); _feedTimer?.cancel();
    _ambient.dispose(); _takeoverAnimation.dispose();
    _ble.stopAdvertising(); WakelockPlus.disable();
    super.dispose();
  }

  String get _remaining {
    if (_endsAt == null) return '—';
    final seconds = _endsAt!.difference(DateTime.now()).inSeconds.clamp(0, 999999);
    return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
  double get _timeProgress {
    final start = DateTime.tryParse('${widget.session['startedAt'] ?? ''}');
    if (start == null || _endsAt == null) return 0;
    final total = _endsAt!.difference(start).inSeconds;
    if (total <= 0) return 1;
    return (1 - _endsAt!.difference(DateTime.now()).inSeconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final present = _students.where((student) => student['present'] == true).length;
    final total = _students.length;
    final absent = total - present;
    final courseTitle = '${widget.course['code'] ?? ''} — ${widget.course['name'] ?? ''}';
    return AppScaffold(
      appBar: AppBar(title: const Text('Live session'), actions: [IconButton(onPressed: _loadReport, icon: const Icon(Icons.refresh), tooltip: 'Refresh attendance')]),
      body: Stack(children: [
        Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: _ambient, builder: (context, _) => CustomPaint(painter: _AmbientCirclesPainter(_ambient.value, Theme.of(context).colorScheme.primary))))),
        if (_takeover) _BroadcastTakeover(controller: _takeoverAnimation, code: _code),
        if (!_takeover) SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
          AppCard(child: Column(children: [
            Text(courseTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 13), SessionCodeDisplay(code: _code),
            const SizedBox(height: 15),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 86, height: 86, child: Stack(alignment: Alignment.center, children: [CircularProgressIndicator(value: _timeProgress, strokeWidth: 6, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .14)), Column(mainAxisSize: MainAxisSize.min, children: [Text(_remaining, style: Theme.of(context).textTheme.titleMedium), Text('remaining', style: Theme.of(context).textTheme.labelSmall)])])),
              const SizedBox(width: 16), _BroadcastPill(broadcasting: _broadcasting && !_ended),
            ]),
            if (_notice != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_notice!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)),
            if (_broadcastError != null && !_ended) Padding(padding: const EdgeInsets.only(top: 12), child: ErrorState(title: 'Broadcast stopped', message: _broadcastError!, onRetry: _broadcastBusy ? () {} : startBroadcast)),
          ])),
          const SizedBox(height: 14),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('$present / $total present', style: Theme.of(context).textTheme.titleLarge), IconButton(onPressed: _loadReport, tooltip: 'Refresh', icon: const Icon(Icons.refresh))]),
            const SizedBox(height: 5), LinearProgressIndicator(value: total == 0 ? 0 : present / total, minHeight: 8, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 14),
            if (_reportLoading && !_reportLoaded) const SkeletonList(count: 2)
            else if (_reportError != null) ErrorState(message: _reportError!, onRetry: _loadReport, title: 'Attendance unavailable')
            else if (present == 0) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: EmptyState(icon: Icons.wifi_tethering, title: 'Waiting for students...', message: 'Students in your class will appear here when they mark attendance.'))
            else _LiveFeed(entries: _feed),
          ])),
          const SizedBox(height: 8),
          Card(child: ExpansionTile(title: Text('Full attendance list ($present present, $absent absent)'), initiallyExpanded: _listExpanded, onExpansionChanged: (value) => setState(() => _listExpanded = value), children: [
            if (_reportLoading && !_reportLoaded) const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 3))
            else if (_reportError != null && !_reportLoaded) Padding(padding: const EdgeInsets.all(16), child: Text(_reportError!))
            else if (_students.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('No students in this class yet.'))
            else ..._students.map((student) => ListTile(dense: true, leading: Icon(student['present'] == true ? Icons.check_circle : Icons.radio_button_unchecked, color: student['present'] == true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant), title: Text('${student['fullName'] ?? ''}'), subtitle: Text('${student['matricule'] ?? ''}'), trailing: Text(student['present'] == true ? 'Present' : 'Absent'))),
          ])),
          if (!_ended) ...[
            const SizedBox(height: 16), PrimaryButton(label: _ending ? 'Ending…' : 'End session', icon: Icons.stop_circle_outlined, loading: _ending, onPressed: _ending ? null : _endSession),
          ] else ...[
            const SizedBox(height: 14), AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Session summary', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8), Text('$present present  •  $absent absent  •  $total total'), const SizedBox(height: 14), PrimaryButton(label: 'Export attendance PDF', icon: Icons.picture_as_pdf_outlined, onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SessionReportScreen(session: widget.session, user: widget.user))))])),
          ],
        ])),
      ]),
    );
  }
}

class _Arrival {
  const _Arrival({required this.name, required this.id, required this.addedAt});
  final String name, id;
  final DateTime addedAt;
  String get initials => name.trim().split(RegExp(r'\s+')).take(2).map((part) => part.isEmpty ? '' : part[0].toUpperCase()).join();
}

class _LiveFeed extends StatelessWidget {
  const _LiveFeed({required this.entries});
  final List<_Arrival> entries;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (entries.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Waiting for students...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)))
    else ...entries.map((entry) => _FeedPill(entry: entry)),
  ]);
}

class _FeedPill extends StatefulWidget {
  const _FeedPill({required this.entry});
  final _Arrival entry;
  @override
  State<_FeedPill> createState() => _FeedPillState();
}

class _FeedPillState extends State<_FeedPill> with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))..forward();
  @override
  void dispose() { _slide.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(widget.entry.addedAt).inSeconds;
    final scheme = Theme.of(context).colorScheme;
    final pill = DecoratedBox(
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .11), borderRadius: BorderRadius.circular(30), border: Border.all(color: scheme.primary.withValues(alpha: .3))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 13, backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary, child: Text(widget.entry.initials, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Text('${widget.entry.name} is present', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: FadeTransition(
        opacity: AlwaysStoppedAnimation((1 - age / 8).clamp(.2, 1.0)),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(-.2, 0), end: Offset.zero).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOut)),
          child: Align(alignment: Alignment.centerLeft, child: pill),
        ),
      ),
    );
  }
}

class _BroadcastPill extends StatefulWidget {
  const _BroadcastPill({required this.broadcasting});
  final bool broadcasting;
  @override
  State<_BroadcastPill> createState() => _BroadcastPillState();
}
class _BroadcastPillState extends State<_BroadcastPill> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final color = widget.broadcasting ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error;
    return DecoratedBox(decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withValues(alpha: .5))), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9), child: Row(mainAxisSize: MainAxisSize.min, children: [AnimatedBuilder(animation: _pulse, builder: (context, _) => Container(width: 9, height: 9, decoration: BoxDecoration(color: color.withValues(alpha: widget.broadcasting ? .55 + _pulse.value * .45 : 1), shape: BoxShape.circle))), const SizedBox(width: 7), Text(widget.broadcasting ? 'Broadcasting' : 'Stopped', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color))])));
  }
}

class _BroadcastTakeover extends StatelessWidget {
  const _BroadcastTakeover({required this.controller, required this.code});
  final AnimationController controller;
  final String code;
  @override
  Widget build(BuildContext context) => Positioned.fill(child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: AnimatedBuilder(animation: controller, builder: (context, _) {
    final revealCode = controller.value >= .48;
    final opacity = controller.value < .2 ? controller.value / .2 : controller.value > .85 ? (1 - controller.value) / .15 : 1.0;
    return Stack(alignment: Alignment.center, children: [CustomPaint(size: Size.infinite, painter: _TakeoverCirclesPainter(controller.value, Theme.of(context).colorScheme.primary)), Column(mainAxisSize: MainAxisSize.min, children: [Text('Broadcasting', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary)), const SizedBox(height: 16), Opacity(opacity: revealCode ? opacity.clamp(0.0, 1.0) : 0, child: Text(code, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontFamily: 'monospace', letterSpacing: 8, color: Theme.of(context).colorScheme.onSurface)))] )]);
  })));
}

class _AmbientCirclesPainter extends CustomPainter {
  const _AmbientCirclesPainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .85, size.height * .72);
    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1;
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = color.withValues(alpha: .045 * (1 - phase));
      canvas.drawCircle(center, 18 + phase * size.shortestSide * .55, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _AmbientCirclesPainter old) => old.progress != progress || old.color != color;
}

class _TakeoverCirclesPainter extends CustomPainter {
  const _TakeoverCirclesPainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) * .58;
    for (var i = 0; i < 5; i++) {
      final phase = (progress - i * .12).clamp(0.0, 1.0);
      if (phase <= 0) continue;
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2 + (1 - phase) * 4..color = color.withValues(alpha: (1 - phase) * .42);
      canvas.drawCircle(center, 18 + phase * maxRadius, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _TakeoverCirclesPainter old) => old.progress != progress || old.color != color;
}
