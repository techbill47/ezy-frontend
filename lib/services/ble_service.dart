import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

const String ezyServiceUuid = '7f510001-1b15-4f0d-8b87-55a2d4e93c01';
const MethodChannel _nativeBle = MethodChannel('ezy/ble_test');

class SessionSignal {
  const SessionSignal({required this.departmentId, required this.year, required this.code, required this.rssi, required this.detectedAt});
  final int departmentId, year, rssi;
  final String code;
  final DateTime detectedAt;
}

class BleServiceException implements Exception {
  const BleServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BleService {
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  bool _advertising = false;
  bool _scanning = false;
  bool heardOtherClass = false;

  Future<bool> _requestPermissions(BuildContext context, {required bool advertise}) async {
    final message = 'EZY needs Bluetooth ${advertise ? 'advertise, ' : ''}scan and connect access to ${advertise ? 'broadcast this session code' : 'find your class session'}.${Platform.isAndroid ? ' On Android 11 or older, location access is also needed for BLE scanning.' : ''}';
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Bluetooth permission needed'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue'))]));
    if (accepted != true) throw const BleServiceException('Bluetooth permission was not granted. Tap Retry to try again.');
    final requested = <Permission>[Permission.bluetoothScan, Permission.bluetoothConnect, if (advertise) Permission.bluetoothAdvertise];
    final sdk = Platform.isAndroid ? await _nativeBle.invokeMethod<int>('sdkInt') : null;
    if (Platform.isAndroid && (sdk ?? 0) <= 30) requested.add(Permission.locationWhenInUse);
    final result = await requested.request();
    final denied = result.entries.where((entry) => !entry.value.isGranted).map((entry) => entry.key.toString().split('.').last).join(', ');
    if (denied.isNotEmpty) throw BleServiceException('Permission denied: $denied. Allow the requested access in Android settings, then tap Retry.');
    return true;
  }

  Future<void> _checkBluetooth() async {
    if (!await FlutterBluePlus.isSupported) throw const BleServiceException('This phone does not support Bluetooth LE.');
    final state = await FlutterBluePlus.adapterState.first.timeout(const Duration(seconds: 5));
    if (state != BluetoothAdapterState.on) throw const BleServiceException('Bluetooth is off. Turn it on in Android settings, then tap Retry.');
  }

  Future<void> startAdvertising(BuildContext context, int departmentId, int year, String code) async {
    if (departmentId < 0 || departmentId > 255 || year < 1 || year > 255 || !RegExp(r'^[A-Z2-9]{6}$').hasMatch(code)) throw const BleServiceException('The class tag or session code is invalid.');
    await _requestPermissions(context, advertise: true);
    await _checkBluetooth();
    if (!await _peripheral.isSupported) throw const BleServiceException('This phone does not support BLE advertising.');
    try {
      final payload = [departmentId, year, ...ascii.encode(code)];
      final state = await _peripheral.start(advertiseData: AndroidAdvertiseData(serviceDataUuid: ezyServiceUuid, serviceData: payload));
      if (state != PeripheralBluetoothState.ready) throw BleServiceException('Bluetooth advertising did not start ($state).');
      _advertising = true;
    } catch (error) {
      _advertising = false;
      if (error is BleServiceException) rethrow;
      throw BleServiceException('Could not start Bluetooth advertising: $error');
    }
  }

  Future<void> stopAdvertising() async {
    if (!_advertising) return;
    await _peripheral.stop();
    _advertising = false;
  }

  Future<SessionSignal?> scanForSession(BuildContext context, int departmentId, int year) async {
    heardOtherClass = false;
    await _requestPermissions(context, advertise: false);
    await _checkBluetooth();
    final serviceGuid = Guid(ezyServiceUuid);
    SessionSignal? best;
    var foundAnySignal = false;
    Object? scanError;
    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final payload = result.advertisementData.serviceData[serviceGuid];
        if (payload == null || payload.length != 8) continue;
        final code = ascii.decode(payload.sublist(2), allowInvalid: true);
        if (!RegExp(r'^[A-Z2-9]{6}$').hasMatch(code)) continue;
        foundAnySignal = true;
        if (payload[0] != departmentId || payload[1] != year) { heardOtherClass = true; continue; }
        if (best == null || result.rssi > best!.rssi) best = SessionSignal(departmentId: payload[0], year: payload[1], code: code, rssi: result.rssi, detectedAt: DateTime.now());
      }
    }, onError: (Object error) { scanError = error; });
    _scanning = true;
    try {
      await FlutterBluePlus.startScan(withServices: [serviceGuid], timeout: const Duration(seconds: 10), oneByOne: true);
      if (scanError != null) throw BleServiceException('Bluetooth scan failed: $scanError');
      return best;
    } catch (error) {
      throw BleServiceException('Bluetooth scan failed: $error');
    } finally {
      _scanning = false;
      await subscription.cancel();
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
      if (!foundAnySignal) heardOtherClass = false;
    }
  }

  Future<void> stopScan() async { if (_scanning) await FlutterBluePlus.stopScan(); _scanning = false; }
}
