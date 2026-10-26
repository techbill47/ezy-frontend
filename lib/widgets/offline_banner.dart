import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.role, this.offlineOverride});
  final String role;
  final bool? offlineOverride;
  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}
class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offline = false;
  @override
  void initState() {
    super.initState();
    if (widget.offlineOverride != null) { _offline = widget.offlineOverride!; return; }
    Connectivity().checkConnectivity().then(_update);
    _subscription = Connectivity().onConnectivityChanged.listen(_update);
  }
  void _update(List<ConnectivityResult> result) { if (mounted) setState(() => _offline = result.contains(ConnectivityResult.none)); }
  @override
  void dispose() { _subscription?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();
    final student = widget.role == 'student';
    final scheme = Theme.of(context).colorScheme;
    return Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: scheme.errorContainer, border: Border(bottom: BorderSide(color: scheme.error.withValues(alpha: .4)))), child: Row(children: [Icon(Icons.wifi_off, size: 18, color: scheme.onErrorContainer), const SizedBox(width: 9), Expanded(child: Text(student ? 'Offline — attendance marks are saved and will sync when you reconnect.' : 'Offline — connect to the internet to start sessions or load reports.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer)))]));
  }
}
