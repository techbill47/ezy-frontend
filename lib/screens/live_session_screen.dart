import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../api/api_client.dart';
import '../models/app_user.dart';
import '../services/ble_service.dart';
import '../services/session_service.dart';

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({super.key, required this.session, required this.course, required this.user, required this.resumed});
  final Map<String, dynamic> session, course;
  final AppUser user;
  final bool resumed;
  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}
class _LiveSessionScreenState extends State<LiveSessionScreen> with WidgetsBindingObserver {
  final BleService _ble = BleService();
  Timer? _clock, _refreshTimer;
  List<Map<String, dynamic>> _students = [];
  DateTime? _endsAt;
  String? _error, _notice;
  bool _broadcasting = false, _busy = false, _ended = false, _reportLoading = true, _paused = false;
  String get _id => '${widget.session['id'] ?? ''}';
  String get _code => '${widget.session['code'] ?? ''}';
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    final raw = widget.session['endsAt'] ?? (widget.session['session'] is Map ? widget.session['session']['endsAt'] : null);
    _endsAt = DateTime.tryParse('$raw');
    _ended = '${widget.session['status'] ?? ''}' == 'ended' || (_endsAt != null && !_endsAt!.isAfter(DateTime.now()));
    WakelockPlus.enable();
    if (widget.resumed) _notice = 'An active session already existed. This screen has resumed it.';
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadReport());
    _loadReport();
    if (!_ended) startBroadcast();
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
    if (_busy || _ended) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _ble.startAdvertising(context, widget.user.departmentId, widget.user.year, _code);
      if (mounted) setState(() { _broadcasting = true; _paused = false; _error = null; });
    } catch (error) { if (mounted) setState(() { _broadcasting = false; _error = error.toString(); }); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _loadReport() async {
    if (_reportLoading && _students.isNotEmpty) return;
    setState(() => _reportLoading = true);
    try {
      final report = await ApiClient(token: context.read<SessionService>().token).get('/api/sessions/$_id/report');
      if (report is! Map || report['students'] is! List) throw ApiException('The server returned an invalid attendance report.');
      final people = (report['students'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()..sort((a, b) { final present = (b['present'] == true ? 1 : 0).compareTo(a['present'] == true ? 1 : 0); return present != 0 ? present : '${a['fullName'] ?? ''}'.compareTo('${b['fullName'] ?? ''}'); });
      if (mounted) setState(() { _students = people; _error = null; });
    } catch (error) { if (mounted && _error == null) setState(() => _error = 'Attendance list could not refresh: $error'); }
    finally { if (mounted) setState(() => _reportLoading = false); }
  }
  Future<void> _endSession() async {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('End session?'), content: const Text('Students will no longer be able to mark attendance for this session.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('End session'))]));
    if (accepted != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ApiClient(token: context.read<SessionService>().token).post('/api/sessions/$_id/end');
      await _ble.stopAdvertising();
      await WakelockPlus.disable();
      if (mounted) setState(() { _ended = true; _broadcasting = false; _notice = 'Session ended.'; });
    } catch (error) { if (mounted) setState(() => _error = 'Could not end the session: $error'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      if (_broadcasting) { _ble.stopAdvertising(); if (mounted) setState(() { _broadcasting = false; _paused = true; }); }
      WakelockPlus.disable();
    } else if (state == AppLifecycleState.resumed && mounted) {
      WakelockPlus.enable();
      if (_paused) setState(() { _notice = 'Broadcast stopped while you were away. Tap Retry to broadcast again.'; _error = 'Broadcast stopped while the app was away.'; });
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); _clock?.cancel(); _refreshTimer?.cancel();
    _ble.stopAdvertising(); WakelockPlus.disable(); super.dispose();
  }
  String get _remaining {
    if (_endsAt == null) return 'End time unavailable';
    final seconds = _endsAt!.difference(DateTime.now()).inSeconds.clamp(0, 999999);
    return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')} remaining';
  }
  @override
  Widget build(BuildContext context) {
    final present = _students.where((student) => student['present'] == true).length;
    return Scaffold(appBar: AppBar(title: const Text('Live session')), body: RefreshIndicator(onRefresh: _loadReport, child: ListView(padding: const EdgeInsets.all(20), children: [
      Text('${widget.course['code'] ?? ''} — ${widget.course['name'] ?? ''}', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16), Center(child: SelectableText(_code, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 8))),
      Center(child: Text(_remaining)), const SizedBox(height: 12),
      Text(_ended ? 'Session ended' : _broadcasting ? 'Broadcasting' : 'Not broadcasting', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      if (_notice != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_notice!, textAlign: TextAlign.center)),
      if (_error != null) ...[Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))), if (!_ended) OutlinedButton(onPressed: _busy ? null : startBroadcast, child: const Text('Retry broadcast'))],
      if (_busy) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
      const SizedBox(height: 18), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Present: $present / ${_students.length}', style: Theme.of(context).textTheme.titleMedium), IconButton(onPressed: _loadReport, icon: const Icon(Icons.refresh), tooltip: 'Refresh attendance')]),
      if (_reportLoading && _students.isEmpty) const Center(child: CircularProgressIndicator()) else if (_students.isEmpty) const Text('No students in this class yet.') else ..._students.map((s) => ListTile(leading: Icon(s['present'] == true ? Icons.check_circle : Icons.radio_button_unchecked, color: s['present'] == true ? Colors.green : null), title: Text('${s['fullName'] ?? ''}'), subtitle: Text('${s['matricule'] ?? ''}'), trailing: Text(s['present'] == true ? 'Present' : 'Absent'))),
      if (!_ended) SizedBox(height: 56, child: FilledButton.tonal(onPressed: _busy ? null : _endSession, child: const Text('End session'))),
    ])));
  }
}
