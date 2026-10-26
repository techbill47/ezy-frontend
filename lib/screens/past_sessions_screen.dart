import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/app_user.dart';
import '../services/session_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/offline_banner.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'session_report_screen.dart';

class PastSessionsScreen extends StatefulWidget {
  const PastSessionsScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<PastSessionsScreen> createState() => _PastSessionsScreenState();
}

class _PastSessionsScreenState extends State<PastSessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiClient(token: context.read<SessionService>().token).get('/api/sessions');
      if (result is! List) throw ApiException('The server returned an invalid sessions list.');
      if (mounted) setState(() => _sessions = result.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList());
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Past sessions')),
    body: Column(children: [
      const OfflineBanner(role: 'coordinator'),
      Expanded(child: RefreshIndicator(onRefresh: _load, child: _loading
        ? ListView(padding: const EdgeInsets.all(18), children: const [SkeletonList(count: 6)])
        : _error != null
          ? ListView(children: [SizedBox(height: MediaQuery.sizeOf(context).height * .18), ErrorState(title: 'Sessions unavailable', message: _error!, onRetry: _load)])
          : _sessions.isEmpty
            ? ListView(children: [SizedBox(height: MediaQuery.sizeOf(context).height * .18), EmptyState(icon: Icons.history, title: 'No past sessions', message: 'Sessions you start will appear here with their attendance totals.')])
            : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                Text('Your sessions', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                ..._sessions.map((session) {
                  final date = DateTime.tryParse('${session['startedAt']}')?.toLocal();
                  final ended = '${session['status'] ?? ''}'.toLowerCase() == 'ended';
                  final dateText = date == null ? 'Date unavailable' : DateFormat('EEE, d MMM yyyy').format(date);
                  final timeText = date == null ? 'Time unavailable' : DateFormat('h:mm a').format(date);
                  return AppCard(onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SessionReportScreen(session: session, user: widget.user))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text('${session['courseCode'] ?? ''}', style: Theme.of(context).textTheme.titleLarge)), StatusPill(label: ended ? 'Ended' : 'Active', kind: ended ? StatusKind.neutral : StatusKind.success)]),
                    const SizedBox(height: 4),
                    Text('${session['courseName'] ?? ''}', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Wrap(spacing: 16, runSpacing: 8, children: [Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.calendar_today_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 7), Text(dateText)]), Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.schedule, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 7), Text(timeText)])]),
                    const SizedBox(height: 10),
                    Row(children: [Icon(Icons.people_alt_outlined, size: 17, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 7), Text('${session['presentCount'] ?? 0} present', style: Theme.of(context).textTheme.titleSmall), const Spacer(), const Icon(Icons.chevron_right)]),
                  ]));
                }),
              ]))),
    ]),
  );
}
