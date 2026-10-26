import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'screens/ble_test_screen.dart';
import 'config.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  String? _result;
  String? _serverTime;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/health'),
            headers: const {'ngrok-skip-browser-warning': 'true'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['ok'] == true) {
          _result = 'Backend OK';
          _serverTime = body['time']?.toString();
        } else {
          _result = 'Unexpected health response: ${response.body}';
        }
      } else {
        _result =
            'Backend returned HTTP ${response.statusCode}: ${response.body}';
      }
    } catch (error) {
      _result = 'Could not reach backend at $apiBaseUrl/health: $error';
      _serverTime = null;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('EZY connection check'),
      actions: [
        IconButton(
          tooltip: 'BLE test',
          icon: const Icon(Icons.bluetooth_searching),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BleTestScreen()),
          ),
        ),
      ],
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('API: $apiBaseUrl', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _checkHealth,
              child: Text(_loading ? 'Checking…' : 'Retry'),
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            if (_result != null) ...[
              SelectableText(_result!),
              if (_serverTime != null) Text('Server time: $_serverTime'),
            ],
          ],
        ),
      ),
    ),
  );
}
