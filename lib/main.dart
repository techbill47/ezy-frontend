import 'package:flutter/material.dart';

import 'health_screen.dart';

void main() => runApp(const EzyApp());

class EzyApp extends StatelessWidget {
  const EzyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EZY',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E5BD8),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
    ),
    home: const HealthScreen(),
  );
}
