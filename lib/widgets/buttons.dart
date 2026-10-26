import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final child = loading ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Theme.of(context).colorScheme.onPrimary)) : Text(label);
    return ConstrainedBox(constraints: const BoxConstraints(minHeight: 52), child: icon != null && !loading ? FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: child) : FilledButton(onPressed: loading ? null : onPressed, child: child));
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => ConstrainedBox(constraints: const BoxConstraints(minHeight: 52), child: icon == null ? OutlinedButton(onPressed: onPressed, child: Text(label)) : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label)));
}
