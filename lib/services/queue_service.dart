import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import 'notification_service.dart';
import 'session_service.dart';

class QueueService extends ChangeNotifier with WidgetsBindingObserver {
  static const _queueKey = 'attendance_queue_v1', _historyKey = 'attendance_history_v1';
  final List<Map<String, dynamic>> _queue = [];
  final List<Map<String, dynamic>> _history = [];
  SessionService? _session;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _ready = false, _syncing = false;
  String? lastSyncResult;

  bool get ready => _ready;
  bool get syncing => _syncing;
  int pendingFor(String userId) => _queue.where((item) => item['ownerId'] == userId).length;
  List<Map<String, dynamic>> historyFor(String userId) => _history.where((item) => item['ownerId'] == userId).take(10).map(Map<String, dynamic>.from).toList();

  Future<void> initialize(SessionService session) async {
    _session = session;
    final prefs = await SharedPreferences.getInstance();
    _queue
      ..clear()
      ..addAll(_decodeList(prefs.getString(_queueKey)));
    _history
      ..clear()
      ..addAll(_decodeList(prefs.getString(_historyKey)));
    _ready = true;
    session.addListener(_onSessionChanged);
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) unawaited(syncNow());
    });
    notifyListeners();
    unawaited(syncNow());
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(); }
    catch (_) { return []; }
  }
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(_queue));
    await prefs.setString(_historyKey, jsonEncode(_history));
  }
  void _onSessionChanged() { if (_session?.user?.role == 'student' && _session?.token != null) unawaited(syncNow()); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) unawaited(syncNow()); }

  Future<bool> addMark(String sessionCode, String detectedAt, String ownerId) async {
    if (_history.any((item) => item['ownerId'] == ownerId && item['sessionCode'] == sessionCode)) return false;
    final item = <String, dynamic>{'sessionCode': sessionCode, 'detectedAt': detectedAt, 'ownerId': ownerId, 'status': 'pending'};
    _queue.insert(0, item);
    _history.insert(0, Map<String, dynamic>.from(item));
    if (_history.length > 50) _history.removeRange(50, _history.length);
    await _save();
    notifyListeners();
    final detected = DateTime.tryParse(detectedAt);
    if (detected != null) unawaited(NotificationService.instance.attendanceMarked(sessionCode: sessionCode, detectedAt: detected));
    unawaited(syncNow());
    return true;
  }

  Future<void> syncNow() async {
    if (!_ready || _syncing) return;
    final session = _session;
    final user = session?.user;
    if (session?.token == null || user == null || user.role != 'student') return;
    final ownerId = user.id;
    final token = session!.token!;
    final pending = _queue.where((item) => item['ownerId'] == ownerId).toList();
    if (pending.isEmpty) { lastSyncResult ??= 'Nothing waiting to sync.'; notifyListeners(); return; }
    _syncing = true;
    notifyListeners();
    var synced = 0, rejected = 0;
    final reasons = <String>[];
    try {
      while (true) {
        final batch = _queue.where((item) => item['ownerId'] == ownerId).take(100).toList();
        if (batch.isEmpty) break;
        final response = await ApiClient(token: token).post('/api/attendance/sync', {'items': batch.map((item) => {'sessionCode': item['sessionCode'], 'detectedAt': item['detectedAt']}).toList()});
        if (response is! Map || response['results'] is! List) throw ApiException('The server returned an invalid sync response.');
        final byCode = <String, Map<String, dynamic>>{};
        for (final raw in response['results'] as List) { if (raw is Map) { final result = Map<String, dynamic>.from(raw); byCode['${result['sessionCode']}'] = result; } }
        var removedFromBatch = 0;
        for (final item in batch) {
          final result = byCode['${item['sessionCode']}'];
          final status = result?['status'];
          if (status != 'ok' && status != 'duplicate' && status != 'rejected') continue;
          _queue.remove(item); removedFromBatch++;
          final rejectedMark = status == 'rejected';
          if (rejectedMark) { rejected++; final reason = '${result?['reason'] ?? 'The server rejected this mark.'}'; reasons.add(reason); _updateHistory(item, 'rejected', reason); }
          else { synced++; _updateHistory(item, 'synced', null); }
        }
        await _save(); notifyListeners();
        if (removedFromBatch == 0) break;
      }
      lastSyncResult = 'Synced: $synced. Rejected: $rejected.${reasons.isEmpty ? '' : ' Reasons: ${reasons.join('; ')}'}';
    } catch (error) {
      lastSyncResult = 'Will retry. ${error is ApiException ? error.message : error}';
    } finally {
      if (synced > 0) unawaited(NotificationService.instance.recordsSynced(synced));
      for (final reason in reasons) { unawaited(NotificationService.instance.recordRejected(reason)); }
      _syncing = false;
      notifyListeners();
    }
  }

  void _updateHistory(Map<String, dynamic> item, String status, String? reason) {
    final entry = _history.firstWhere((row) => row['ownerId'] == item['ownerId'] && row['sessionCode'] == item['sessionCode'], orElse: () => item);
    entry['status'] = status;
    if (reason != null) entry['reason'] = reason;
  }

  @override
  void dispose() {
    _session?.removeListener(_onSessionChanged);
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
