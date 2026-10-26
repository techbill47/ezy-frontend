import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const attendanceChannelId = 'attendance_channel';
  static const sessionChannelId = 'session_channel';
  static const _attendanceEnabledKey = 'notifications_attendance_enabled';
  static const _sessionEnabledKey = 'notifications_session_enabled';
  static const _attendanceIdsKey = 'notifications_attendance_ids';
  static const _sessionIdsKey = 'notifications_session_ids';
  static const _defaultIcon = '@mipmap/ic_launcher';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _pendingTapPayload;

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      const settings = InitializationSettings(android: AndroidInitializationSettings(_defaultIcon));
      await _plugin.initialize(settings: settings, onDidReceiveNotificationResponse: _onNotificationResponse);
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(attendanceChannelId, 'Attendance', description: 'Attendance marks and sync updates.', importance: Importance.defaultImportance));
      await android?.createNotificationChannel(const AndroidNotificationChannel(sessionChannelId, 'Session', description: 'Coordinator session reminders and status.', importance: Importance.high));
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) _pendingTapPayload = launch?.notificationResponse?.payload;
      _initialized = true;
    } catch (_) {
      // Notifications are optional and must never prevent the app from opening.
    }
  }

  Future<bool> requestPermission(BuildContext context) async {
    if (!Platform.isAndroid) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      if (await android.areNotificationsEnabled() == true) return true;
      if (!context.mounted) return false;
      final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Allow attendance notifications?'),
        content: const Text('EZY can notify you when attendance is marked or synced, or when a coordinator session is about to end. You can turn Attendance and Session notifications on or off later in Settings.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not now')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Continue'))],
      ));
      if (accepted != true) return false;
      final granted = await android.requestNotificationsPermission();
      return granted ?? await android.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> attendanceEnabled() async => (await SharedPreferences.getInstance()).getBool(_attendanceEnabledKey) ?? true;
  Future<bool> sessionEnabled() async => (await SharedPreferences.getInstance()).getBool(_sessionEnabledKey) ?? true;
  Future<void> setAttendanceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_attendanceEnabledKey, enabled);
    if (!enabled) await _cancelChannel(attendanceChannelId);
  }
  Future<void> setSessionEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionEnabledKey, enabled);
    if (!enabled) await _cancelChannel(sessionChannelId);
  }

  Future<bool> _channelEnabled(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    final preferenceKey = channelId == attendanceChannelId ? _attendanceEnabledKey : _sessionEnabledKey;
    if (!(prefs.getBool(preferenceKey) ?? true)) return false;
    if (!Platform.isAndroid) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    } catch (_) { return false; }
  }

  Future<void> attendanceMarked({required String sessionCode, required DateTime detectedAt}) async {
    if (!await _channelEnabled(attendanceChannelId)) return;
    final time = '${detectedAt.toLocal().hour.toString().padLeft(2, '0')}:${detectedAt.toLocal().minute.toString().padLeft(2, '0')}';
    await _show(id: _stableId('mark:$sessionCode'), title: 'Attendance marked', body: 'Attendance marked: Session $sessionCode at $time', channelId: attendanceChannelId, payload: {'route': '/my-attendance'});
  }

  Future<void> recordsSynced(int count) async {
    if (count <= 0 || !await _channelEnabled(attendanceChannelId)) return;
    await _show(id: _stableId('sync:${DateTime.now().millisecondsSinceEpoch}'), title: 'Attendance synced', body: 'Synced $count records', channelId: attendanceChannelId, payload: {'route': '/my-attendance'});
  }

  Future<void> recordRejected(String reason) async {
    if (!await _channelEnabled(attendanceChannelId)) return;
    await _show(id: _stableId('rejected:${DateTime.now().millisecondsSinceEpoch}:$reason'), title: 'Attendance record rejected', body: 'A record was rejected: $reason', channelId: attendanceChannelId, payload: {'route': '/my-attendance'});
  }

  Future<void> scheduleSessionReminder({required String sessionId, required DateTime endsAt, required Map<String, dynamic> session, required Map<String, dynamic> course}) async {
    await cancelSessionReminder(sessionId);
    final reminderAt = endsAt.subtract(const Duration(minutes: 5));
    if (!reminderAt.isAfter(DateTime.now()) || !await _channelEnabled(sessionChannelId)) return;
    final routePayload = _livePayload(session, course);
    try {
      await _plugin.zonedSchedule(
        id: _reminderId(sessionId),
        title: 'Session ending soon',
        body: 'Session ends in 5 minutes',
        scheduledDate: tz.TZDateTime.from(reminderAt.toUtc(), tz.UTC),
        notificationDetails: _details(sessionChannelId),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode(routePayload),
      );
      await _rememberId(sessionChannelId, _reminderId(sessionId));
    } catch (_) { /* Permission, alarm, or device restrictions must not affect the session. */ }
  }

  Future<void> cancelSessionReminder(String sessionId) async {
    final id = _reminderId(sessionId);
    try { await _plugin.cancel(id: id); } catch (_) { }
    await _forgetId(sessionChannelId, id);
  }

  Future<void> sessionEnded({required String sessionId, required int present, required int total, required Map<String, dynamic> session, required Map<String, dynamic> course}) async {
    await cancelSessionReminder(sessionId);
    await clearBroadcastStopped(sessionId);
    if (!await _channelEnabled(sessionChannelId)) return;
    await _show(id: _sessionEventId(sessionId, 'ended'), title: 'Session ended', body: 'Session ended: $present of $total present', channelId: sessionChannelId, payload: _livePayload({...session, 'status': 'ended'}, course));
  }

  Future<void> broadcastStopped({required String sessionId, required Map<String, dynamic> session, required Map<String, dynamic> course}) async {
    if (!await _channelEnabled(sessionChannelId)) return;
    await _show(id: _sessionEventId(sessionId, 'stopped'), title: 'Broadcast stopped', body: 'Broadcast stopped', channelId: sessionChannelId, payload: _livePayload(session, course));
  }

  Future<void> clearBroadcastStopped(String sessionId) async {
    final id = _sessionEventId(sessionId, 'stopped');
    try { await _plugin.cancel(id: id); } catch (_) { }
    await _forgetId(sessionChannelId, id);
  }

  Map<String, dynamic> _livePayload(Map<String, dynamic> session, Map<String, dynamic> course) => {'route': '/notification-live-session', 'session': session, 'course': course};

  Future<void> _show({required int id, required String title, required String body, required String channelId, required Map<String, dynamic> payload}) async {
    if (!_initialized || !await _channelEnabled(channelId)) return;
    try {
      await _plugin.show(id: id, title: title, body: body, notificationDetails: _details(channelId), payload: jsonEncode(payload));
      await _rememberId(channelId, id);
    } catch (_) { }
  }

  Future<void> _rememberId(String channelId, int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = channelId == attendanceChannelId ? _attendanceIdsKey : _sessionIdsKey;
    final ids = prefs.getStringList(key) ?? <String>[];
    if (!ids.contains('$id')) { ids.add('$id'); await prefs.setStringList(key, ids); }
  }

  Future<void> _forgetId(String channelId, int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = channelId == attendanceChannelId ? _attendanceIdsKey : _sessionIdsKey;
    final ids = prefs.getStringList(key) ?? <String>[];
    ids.remove('$id');
    await prefs.setStringList(key, ids);
  }

  Future<void> _cancelChannel(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = channelId == attendanceChannelId ? _attendanceIdsKey : _sessionIdsKey;
    final ids = prefs.getStringList(key) ?? <String>[];
    for (final value in ids) {
      final id = int.tryParse(value);
      if (id != null) { try { await _plugin.cancel(id: id); } catch (_) { } }
    }
    await prefs.remove(key);
  }

  NotificationDetails _details(String channelId) {
    final attendance = channelId == attendanceChannelId;
    return NotificationDetails(android: AndroidNotificationDetails(channelId, attendance ? 'Attendance' : 'Session', channelDescription: attendance ? 'Attendance marks and sync updates.' : 'Coordinator session reminders and status.', importance: attendance ? Importance.defaultImportance : Importance.high, priority: attendance ? Priority.defaultPriority : Priority.high, icon: _defaultIcon));
  }

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) { hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff; }
    return hash == 0 ? 1 : hash;
  }
  int _reminderId(String sessionId) => _stableId('reminder:$sessionId');
  int _sessionEventId(String sessionId, String event) => _stableId('$event:$sessionId');

  void _onNotificationResponse(NotificationResponse response) => _openPayload(response.payload);

  void openPendingNotification() {
    final payload = _pendingTapPayload;
    _pendingTapPayload = null;
    if (payload != null) _openPayload(payload);
  }

  void _openPayload(String? raw) {
    if (raw == null || raw.isEmpty) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) { _pendingTapPayload = raw; return; }
    try {
      final payload = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final route = payload['route'];
      if (route is String) navigator.pushNamed(route, arguments: payload);
    } catch (_) { }
  }
}
