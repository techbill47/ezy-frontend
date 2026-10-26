import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: padding, child: child)));
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.subtitle});
  final String title;
  final Widget? action;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)])), ?action]);
}

enum StatusKind { success, warning, error, info, neutral }

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.kind = StatusKind.neutral, this.icon});
  final String label;
  final StatusKind kind;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (kind) {
      StatusKind.success => dark ? const Color(0xFF00FF87) : const Color(0xFF008040),
      StatusKind.warning => dark ? const Color(0xFFFFB84D) : const Color(0xFF8A4B00),
      StatusKind.error => dark ? const Color(0xFFFF5C6C) : const Color(0xFFB42336),
      StatusKind.info => dark ? const Color(0xFF85C9FF) : const Color(0xFF075B96),
      StatusKind.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withValues(alpha: .55))), child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 5)], Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))]));
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.icon});
  final String label, value;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [if (icon != null) ...[Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10)], Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))), const SizedBox(width: 12), Flexible(child: Text(value, textAlign: TextAlign.end, style: Theme.of(context).textTheme.titleSmall))]));
}

class AppTextField extends StatelessWidget {
  const AppTextField({super.key, required this.label, this.controller, this.hint, this.obscureText = false, this.keyboardType, this.validator, this.prefixIcon, this.suffixIcon, this.onChanged, this.textCapitalization = TextCapitalization.none, this.maxLength});
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  @override
  Widget build(BuildContext context) => TextFormField(controller: controller, obscureText: obscureText, keyboardType: keyboardType, validator: validator, onChanged: onChanged, textCapitalization: textCapitalization, maxLength: maxLength, decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: prefixIcon == null ? null : Icon(prefixIcon), suffixIcon: suffixIcon, counterText: maxLength == null ? null : ''));
}
