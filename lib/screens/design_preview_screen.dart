import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/offline_banner.dart';
import '../widgets/session_code_display.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';

class DesignPreviewScreen extends StatefulWidget {
  const DesignPreviewScreen({super.key});
  @override
  State<DesignPreviewScreen> createState() => _DesignPreviewScreenState();
}
class _DesignPreviewScreenState extends State<DesignPreviewScreen> {
  final _fieldController = TextEditingController(text: 'MIE101');
  bool _switchValue = true, _choiceValue = true, _filterValue = true;
  @override
  void dispose() { _fieldController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.darkBackground, body: ListView(children: [
    _previewTheme('Dark theme', AppTheme.dark, true),
    _previewTheme('Light theme', AppTheme.light, false),
  ]));

  Widget _previewTheme(String heading, ThemeData theme, bool dark) => Theme(data: theme, child: Builder(builder: (context) => AppScaffold(appBar: AppBar(title: Text(heading)), body: ListView(padding: const EdgeInsets.all(18), children: [
    const SectionHeader('Brand components', subtitle: 'EZY design system preview'),
    const SizedBox(height: 14),
    const SessionCodeDisplay(code: 'ABC234'),
    const SizedBox(height: 14),
    Wrap(spacing: 10, runSpacing: 10, children: [PrimaryButton(label: 'Primary action', icon: Icons.arrow_forward, onPressed: () {}), SecondaryButton(label: 'Secondary action', icon: Icons.tune, onPressed: () {}), const PrimaryButton(label: 'Loading', loading: true, onPressed: null)]),
    const SizedBox(height: 14),
    AppCard(child: Column(children: [const SectionHeader('Account details', action: Icon(Icons.more_horiz)), const InfoRow(label: 'Matricule', value: 'DEMO-S01', icon: Icons.badge_outlined), const InfoRow(label: 'Department', value: 'Mechanical and Industrial Engineering', icon: Icons.school_outlined)])),
    const SizedBox(height: 12),
    Wrap(spacing: 8, runSpacing: 8, children: [const StatusPill(label: 'Success', kind: StatusKind.success, icon: Icons.check_circle_outline), const StatusPill(label: 'Warning', kind: StatusKind.warning, icon: Icons.warning_amber), const StatusPill(label: 'Error', kind: StatusKind.error, icon: Icons.error_outline), const StatusPill(label: 'Info', kind: StatusKind.info, icon: Icons.info_outline), const StatusPill(label: 'Neutral')]),
    const SizedBox(height: 10),
    AppTextField(label: 'Course code', hint: 'For example, MIE101', controller: _fieldController, prefixIcon: Icons.menu_book_outlined),
    const SizedBox(height: 10),
    Wrap(spacing: 8, children: [ChoiceChip(label: const Text('60 minutes'), selected: _choiceValue, onSelected: (v) => setState(() => _choiceValue = v), side: BorderSide(color: _choiceValue ? theme.colorScheme.primary : theme.colorScheme.outline)), FilterChip(label: const Text('Coordinator'), selected: _filterValue, onSelected: (v) => setState(() => _filterValue = v), side: BorderSide(color: _filterValue ? theme.colorScheme.primary : theme.colorScheme.outline))]),
    SwitchListTile(title: const Text('Keep screen awake'), value: _switchValue, onChanged: (v) => setState(() => _switchValue = v)),
    OfflineBanner(role: dark ? 'student' : 'coordinator', offlineOverride: true),
    const SizedBox(height: 10),
    AppCard(padding: EdgeInsets.zero, child: const SizedBox(height: 112, child: LoadingView(message: 'Loading attendance'))),
    const SizedBox(height: 8),
    const SectionHeader('Skeleton loading'),
    const SizedBox(height: 8),
    const AppCard(child: SkeletonList(count: 3)),
    const AppCard(child: EmptyState(icon: Icons.event_available_outlined, title: 'No sessions yet', message: 'Start a session to see attendance here.', actionLabel: 'Start session', onAction: _previewAction)),
    const AppCard(child: ErrorState(title: 'Could not load courses', message: 'Check your connection and try again.', onRetry: _previewAction)),
    const SizedBox(height: 20),
  ]))));
  static void _previewAction() {}
}
