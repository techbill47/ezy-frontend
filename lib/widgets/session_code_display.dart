import 'package:flutter/material.dart';

class SessionCodeDisplay extends StatelessWidget {
  const SessionCodeDisplay({super.key, required this.code, this.caption = 'SESSION CODE'});
  final String code, caption;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: .4))), child: Column(children: [Text(caption, style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 2)), const SizedBox(height: 6), FittedBox(fit: BoxFit.scaleDown, child: Text(code, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontFamily: 'monospace', letterSpacing: 10, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)))]));
}
