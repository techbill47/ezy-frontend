import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../services/ble_service.dart';
import '../services/queue_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/session_code_display.dart';
import '../widgets/surfaces.dart';

enum _ScanResult { marked, wrongClass, notFound, error }

class ListeningOverlayScreen extends StatefulWidget {
  const ListeningOverlayScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<ListeningOverlayScreen> createState() => _ListeningOverlayScreenState();
}

class _ListeningOverlayScreenState extends State<ListeningOverlayScreen> with TickerProviderStateMixin {
  final BleService _ble = BleService();
  late final AnimationController _rings = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300))..repeat();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 720))..repeat(reverse: true);
  late final AnimationController _countdown = AnimationController(vsync: this, duration: const Duration(seconds: 10));
  late final AnimationController _check = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
  late final AnimationController _resultReveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  String _phase = 'Checking Bluetooth';
  _ScanResult? _result;
  String? _detectedAt, _error, _diagnostic;
  String? _sessionCode;
  bool _cancelled = false, _scanning = false;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _scan()); }

  Future<void> _scan() async {
    final started = DateTime.now();
    if (_scanning) return;
    _cancelled = false;
    setState(() { _phase = 'Checking Bluetooth'; _result = null; _error = null; _diagnostic = null; _detectedAt = null; _sessionCode = null; _scanning = true; });
    _rings.repeat(); _pulse.repeat(reverse: true); _countdown.reset(); _check.reset(); _resultReveal.reset();
    try {
      final signal = await _ble.scanForSession(context, widget.user.departmentId, widget.user.year, onListening: () {
        if (!mounted || _cancelled) return;
        setState(() => _phase = 'Listening');
        _countdown.forward(from: 0);
      });
      if (!mounted || _cancelled) return;
      if (signal == null) {
        await _holdMinimumListening(started);
        if (!mounted || _cancelled) return;
        _setResult(_ble.heardOtherClass ? _ScanResult.wrongClass : _ScanResult.notFound);
      } else {
        final detectedAt = DateTime.now().toUtc().toIso8601String();
        _sessionCode = signal.code;
        await context.read<QueueService>().addMark(signal.code, detectedAt, widget.user.id);
        if (!mounted || _cancelled) return;
        _detectedAt = detectedAt;
        await _holdMinimumListening(started);
        if (!mounted || _cancelled) return;
        _setResult(_ScanResult.marked);
        _check.forward(from: 0);
      }
    } catch (error) {
      if (!mounted || _cancelled) return;
      final message = error.toString();
      if (message.contains('none was an EZY session')) {
        _diagnostic = message;
        await _holdMinimumListening(started);
        if (!mounted || _cancelled) return;
        _setResult(_ScanResult.notFound);
      } else {
        _error = message;
        await _holdMinimumListening(started);
        if (!mounted || _cancelled) return;
        _setResult(_ScanResult.error);
      }
    } finally {
      if (mounted && !_cancelled) setState(() => _scanning = false);
      if (!_cancelled) { _countdown.stop(); _rings.stop(); _pulse.stop(); }
    }
  }

  Future<void> _holdMinimumListening(DateTime started) async {
    final remaining = const Duration(seconds: 3) - DateTime.now().difference(started);
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
  }

  void _setResult(_ScanResult result) {
    setState(() { _result = result; _phase = switch (result) { _ScanResult.marked => 'Complete', _ScanResult.wrongClass => 'Class not found', _ScanResult.notFound => 'No session found', _ScanResult.error => 'Bluetooth needs attention' }; });
    _resultReveal.forward(from: 0);
  }

  Future<void> _cancel() async {
    _cancelled = true;
    _scanning = false;
    _countdown.stop(); _rings.stop(); _pulse.stop();
    await _ble.stopScan();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openSettings() async {
    try { await openAppSettings(); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open settings: $error'))); }
  }

  @override
  void dispose() {
    if (_scanning) { _cancelled = true; unawaited(_ble.stopScan()); }
    _countdown.dispose(); _rings.dispose(); _pulse.dispose(); _check.dispose(); _resultReveal.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(appBar: AppBar(title: const Text('Listening for your class...')), body: SafeArea(child: Column(children: [
    Padding(padding: const EdgeInsets.only(top: 8), child: Text(_phase, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary))),
    Expanded(child: Center(child: _result == null ? _listeningView(context) : FadeTransition(opacity: _resultReveal, child: _resultView(context)))),
    Padding(padding: const EdgeInsets.fromLTRB(22, 8, 22, 18), child: _result == null ? SecondaryButton(label: 'Cancel', onPressed: _cancel) : SecondaryButton(label: 'Done', onPressed: () => Navigator.of(context).pop())),
  ])));

  Widget _listeningView(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    SizedBox(width: 270, height: 270, child: AnimatedBuilder(animation: Listenable.merge([_rings, _pulse, _countdown]), builder: (context, _) => CustomPaint(painter: _ListeningPainter(waveProgress: _rings.value, countdownProgress: _countdown.value, accent: Theme.of(context).colorScheme.primary, track: Theme.of(context).colorScheme.outline.withValues(alpha: .35)), child: Center(child: Transform.scale(scale: .82 + _pulse.value * .32, child: Container(width: 17, height: 17, decoration: BoxDecoration(color: AppColors.darkPrimary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.darkPrimary.withValues(alpha: .42), blurRadius: 18, spreadRadius: 5)]))))))),
    const SizedBox(height: 8),
    AnimatedBuilder(animation: _countdown, builder: (context, _) { final remaining = (10 * (1 - _countdown.value)).ceil().clamp(0, 10); return Text(_phase == 'Listening' ? '$remaining seconds' : 'Bluetooth permissions and radio check', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)); }),
  ]);

  Widget _resultView(BuildContext context) {
    final result = _result!;
    if (result == _ScanResult.marked) {
      return SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(animation: _check, builder: (context, _) => CustomPaint(size: const Size(104, 104), painter: _SuccessCheckPainter(_check.value, Theme.of(context).colorScheme.primary))),
      const SizedBox(height: 12), Text('Marked', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
      const SizedBox(height: 16), SessionCodeDisplay(code: _lastCode ?? ''),
      const SizedBox(height: 10), Text(DateTime.tryParse(_detectedAt ?? '')?.toLocal().toString() ?? '', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 10), StatusPill(label: _markStatus, kind: _markStatus == 'synced' ? StatusKind.success : StatusKind.warning),
    ]));
    }
    if (result == _ScanResult.wrongClass) return _messageResult(icon: Icons.wifi_tethering_error_rounded, title: 'No session found for your class', message: 'A session signal was heard, but its class tag does not match your department and year.', retry: true);
    if (result == _ScanResult.notFound) return _messageResult(icon: Icons.bluetooth_searching, title: 'No session found. Move closer and try again', message: _diagnostic, retry: true);
    final lower = (_error ?? '').toLowerCase();
    final permissionError = lower.contains('permission') || lower.contains('denied');
    final bluetoothOff = lower.contains('bluetooth is off');
    return _messageResult(icon: Icons.bluetooth_disabled, title: bluetoothOff ? 'Bluetooth is off' : permissionError ? 'Bluetooth permission needed' : 'Bluetooth scan failed', message: _error ?? 'The scan could not finish.', retry: true, settings: true);
  }

  String? get _lastCode => _sessionCode;
  String get _markStatus => context.watch<QueueService>().historyFor(widget.user.id).where((item) => item['sessionCode'] == _sessionCode).map((item) => '${item['status']}').firstOrNull ?? 'pending';

  Widget _messageResult({required IconData icon, required String title, String? message, required bool retry, bool settings = false}) => SingleChildScrollView(padding: const EdgeInsets.all(26), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 58, color: settings ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary), const SizedBox(height: 14), Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall), if (message != null) ...[const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))], const SizedBox(height: 18), if (retry) PrimaryButton(label: 'Retry', onPressed: _scan), if (settings) ...[const SizedBox(height: 8), SecondaryButton(label: 'Open app settings', icon: Icons.settings_outlined, onPressed: _openSettings)]]));
}

class _ListeningPainter extends CustomPainter {
  const _ListeningPainter({required this.waveProgress, required this.countdownProgress, required this.accent, required this.track});
  final double waveProgress, countdownProgress;
  final Color accent, track;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2;
    for (var i = 0; i < 4; i++) {
      final progress = (waveProgress + i * .25) % 1;
      final radius = 20 + (1 - progress) * 83;
      ring.color = accent.withValues(alpha: (1 - progress) * .5);
      canvas.drawCircle(center, radius, ring);
    }
    final countdownRing = Paint()..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, 112, countdownRing..color = track);
    canvas.drawArc(Rect.fromCircle(center: center, radius: 112), -1.5707963267948966, 6.283185307179586 * countdownProgress, false, countdownRing..color = accent);
  }
  @override
  bool shouldRepaint(covariant _ListeningPainter oldDelegate) => oldDelegate.waveProgress != waveProgress || oldDelegate.countdownProgress != countdownProgress || oldDelegate.accent != accent || oldDelegate.track != track;
}

class _SuccessCheckPainter extends CustomPainter {
  const _SuccessCheckPainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final circlePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = color.withValues(alpha: .25);
    canvas.drawCircle(center, size.width * .42, circlePaint);
    final checkPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = color;
    final path = Path()..moveTo(size.width * .27, size.height * .52)..lineTo(size.width * .44, size.height * .68)..lineTo(size.width * .75, size.height * .35);
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), checkPaint);
  }
  @override
  bool shouldRepaint(covariant _SuccessCheckPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}
