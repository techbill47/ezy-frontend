import 'package:flutter/material.dart';
import '../health_screen.dart';
import 'ble_test_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('EZY')), body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Welcome to EZY'), const SizedBox(height: 16), FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HealthScreen())), child: const Text('Connection check')), OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const BleTestScreen())), child: const Text('BLE test'))])));
}
