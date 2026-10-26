import 'package:flutter/material.dart';
import 'buttons.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading…'});
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium)])));
}

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 18, this.radius = 8});
  final double? width;
  final double height, radius;
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}
class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(animation: _controller, builder: (context, _) => Container(width: widget.width, height: widget.height, decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.radius), gradient: LinearGradient(begin: Alignment(-1.4 + _controller.value * 2.8, 0), end: Alignment(-.4 + _controller.value * 2.8, 0), colors: [scheme.surfaceContainerHighest, scheme.surfaceContainerHighest.withValues(alpha: .55), scheme.surfaceContainerHighest]))));
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});
  final int count;
  @override
  Widget build(BuildContext context) => Column(children: [for (var i = 0; i < count; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [const SkeletonBox(width: 42, height: 42, radius: 14), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SkeletonBox(width: 150 + (i % 2) * 45), const SizedBox(height: 8), SkeletonBox(width: 100 + (i % 3) * 24, height: 13)]))]))]);
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 14), Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center), const SizedBox(height: 8), Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center), if (actionLabel != null && onAction != null) ...[const SizedBox(height: 18), PrimaryButton(label: actionLabel!, onPressed: onAction)]])));
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry, this.title = 'Something went wrong'});
  final String title, message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.error_outline, size: 46, color: Theme.of(context).colorScheme.error), const SizedBox(height: 14), Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center), const SizedBox(height: 8), Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center), const SizedBox(height: 18), SecondaryButton(label: 'Retry', onPressed: onRetry, icon: Icons.refresh)])));
}
