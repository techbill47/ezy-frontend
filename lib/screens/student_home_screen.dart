import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../services/queue_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/offline_banner.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'listening_overlay_screen.dart';
import 'my_attendance_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedTab = 0;
  Future<void> _openListening() async {
    await NotificationService.instance.requestPermission(context);
    if (!mounted) return;
    await Navigator.of(context).push(PageRouteBuilder<void>(opaque: true, transitionDuration: Duration.zero, reverseTransitionDuration: Duration.zero, pageBuilder: (_, _, _) => ListeningOverlayScreen(user: widget.user)));
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('EZY'), actions: [IconButton(tooltip: 'Settings', onPressed: () => Navigator.pushNamed(context, '/settings'), icon: const Icon(Icons.settings_outlined))]),
    bottomNavigationBar: NavigationBar(selectedIndex: _selectedTab, onDestinationSelected: (index) => setState(() => _selectedTab = index), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'), NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'My attendance')]),
    body: _selectedTab == 0 ? _homeBody(context) : MyAttendanceScreen(user: widget.user),
  );

  Widget _homeBody(BuildContext context) {
    final queue = context.watch<QueueService>();
    final firstName = widget.user.fullName.trim().split(RegExp(r'\s+')).first;
    final recent = queue.historyFor(widget.user.id).take(3).toList();
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
      const OfflineBanner(role: 'student'),
      const SizedBox(height: 16),
      Text('Hello, $firstName', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 10),
      _classChip(context),
      const SizedBox(height: 26),
      Center(child: _MarkAttendanceButton(onPressed: _openListening)),
      const SizedBox(height: 28),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('Attendance sync', style: Theme.of(context).textTheme.titleLarge)), StatusPill(label: '${queue.pendingFor(widget.user.id)} pending', kind: queue.pendingFor(widget.user.id) > 0 ? StatusKind.warning : StatusKind.success)]),
        const SizedBox(height: 8),
        Text(queue.lastSyncResult ?? 'Your marks sync automatically when you are online.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: queue.syncing ? null : queue.syncNow, icon: queue.syncing ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync), label: Text(queue.syncing ? 'Syncing…' : 'Sync now'))),
      ])),
      const SizedBox(height: 20),
      SectionHeader('Recent marks', action: TextButton(onPressed: () => setState(() => _selectedTab = 1), child: const Text('View all'))),
      const SizedBox(height: 4),
      if (!queue.ready) const AppCard(child: SkeletonList(count: 2))
      else if (recent.isEmpty) const EmptyState(icon: Icons.event_available_outlined, title: 'No attendance yet', message: 'Mark your first session to see it here.')
      else ...recent.map((mark) => _MarkListTile(mark: mark, onTap: () => _openProof(context, mark))),
    ]));
  }

  Widget _classChip(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(28), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: .45))), child: Row(children: [Icon(Icons.school_outlined, size: 17, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text(widget.user.departmentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary))), const SizedBox(width: 8), Text('Year ${widget.user.year}', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary))]));

  void _openProof(BuildContext context, Map<String, dynamic> mark) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ProofOfAttendanceScreen(mark: mark, user: widget.user)));
}

class _MarkAttendanceButton extends StatelessWidget {
  const _MarkAttendanceButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    width: 246,
    height: 246,
    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.darkPrimary.withValues(alpha: .2), blurRadius: 42, spreadRadius: 5)]),
    child: Material(
      color: AppColors.darkPrimary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Center(child: Padding(padding: const EdgeInsets.all(34), child: Text('Mark attendance', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.darkOnPrimary, fontWeight: FontWeight.w800)))),
      ),
    ),
  );
}

class _MarkListTile extends StatelessWidget {
  const _MarkListTile({required this.mark, required this.onTap});
  final Map<String, dynamic> mark;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = '${mark['status'] ?? 'pending'}';
    final time = DateTime.tryParse('${mark['detectedAt']}')?.toLocal();
    final kind = switch (status) { 'synced' => StatusKind.success, 'rejected' => StatusKind.error, _ => StatusKind.warning };
    return AppCard(padding: EdgeInsets.zero, child: ListTile(onTap: onTap, title: Text('${mark['courseName'] ?? 'Course details unavailable'}'), subtitle: Text('${mark['sessionCode'] ?? ''} · ${time ?? 'Time unavailable'}${status == 'rejected' ? '\n${mark['reason'] ?? 'Rejected by server'}' : ''}'), trailing: StatusPill(label: status, kind: kind)));
  }
}
