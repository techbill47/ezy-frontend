import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart' show ezyServiceUuid;
import 'design_preview_screen.dart';

const int _testManufacturerId = 0xffff;
const _nativeBle = MethodChannel('ezy/ble_test');

enum _BroadcastMode { automatic, serviceData, manufacturerData, deviceName }

class BleTestScreen extends StatefulWidget {
  const BleTestScreen({super.key});

  @override
  State<BleTestScreen> createState() => _BleTestScreenState();
}

class _BleTestScreenState extends State<BleTestScreen> {
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  final Map<String, _FoundSignal> _signals = {};
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  String _encoding = 'Not advertising';
  String? _status;
  bool _advertising = false;
  bool _scanning = false;
  bool _busy = false;
  String? _originalBluetoothName;
  _BroadcastMode _broadcastMode = _BroadcastMode.automatic;

  static final List<int> _payload = [5, 1, ...ascii.encode('ABC234')];

  Future<bool> _explainAndRequestPermissions({required bool advertise}) async {
    final message = advertise
        ? 'EZY needs Bluetooth scan and connect access to check the radio, plus advertise access to broadcast ABC234.${Platform.isAndroid ? ' On Android 11 or older, location access is also needed for BLE scanning.' : ''}'
        : 'EZY needs Bluetooth scan and connect access to look for the EZY service signal.${Platform.isAndroid ? ' On Android 11 or older, location access is also needed for BLE scanning.' : ''}';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth permission needed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (accepted != true) return false;

    final requested = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      if (advertise) Permission.bluetoothAdvertise,
    ];
    final sdk = Platform.isAndroid
        ? await _nativeBle.invokeMethod<int>('sdkInt')
        : null;
    if (Platform.isAndroid && (sdk ?? 0) <= 30) {
      requested.add(Permission.locationWhenInUse);
    }
    final result = await requested.request();
    final denied = result.entries.where((entry) => !entry.value.isGranted);
    if (denied.isNotEmpty) {
      final names = denied
          .map((entry) => entry.key.toString().split('.').last)
          .join(', ');
      setState(() {
        _status =
            'Permission denied: $names. Allow the requested access to use BLE.';
      });
      return false;
    }
    return true;
  }

  Future<bool> _bluetoothIsReady() async {
    if (!await FlutterBluePlus.isSupported) {
      setState(() => _status = 'This phone does not support Bluetooth LE.');
      return false;
    }
    final state = await FlutterBluePlus.adapterState.first.timeout(
      const Duration(seconds: 5),
    );
    if (state != BluetoothAdapterState.on) {
      setState(
        () => _status =
            'Bluetooth is off. Turn it on in Android settings, then try again.',
      );
      return false;
    }
    return true;
  }

  Future<void> _broadcast() async {
    if (_busy || _advertising) return;
    setState(() {
      _busy = true;
      _status = 'Requesting Bluetooth permission…';
      _encoding = 'Trying service data';
    });
    try {
      if (!await _explainAndRequestPermissions(advertise: true)) return;
      if (!await _bluetoothIsReady()) return;
      if (!await _peripheral.isSupported) {
        setState(
          () => _status = 'This phone does not support BLE advertising.',
        );
        return;
      }

      if (_broadcastMode != _BroadcastMode.automatic) {
        final selected = _broadcastMode;
        try {
          await _startSelectedEncoding(selected);
          final name = switch (selected) {
            _BroadcastMode.serviceData => 'Service data',
            _BroadcastMode.manufacturerData => 'Manufacturer data',
            _BroadcastMode.deviceName => 'Device name',
            _BroadcastMode.automatic => 'Automatic fallback',
          };
          setState(() {
            _advertising = true;
            _encoding = name;
            _status = 'Advertising started using $name. Payload: 8 bytes.';
          });
        } catch (error) {
          await _restoreBluetoothName();
          setState(() {
            _encoding = 'Not advertising';
            _status =
                FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on
                ? 'Bluetooth was turned off. Turn it on in Android settings, then try again.'
                : 'Advertising failed using the selected encoding: $error';
          });
        }
        return;
      }

      Object? serviceDataError;
      try {
        await _startAdvertising(
          AndroidAdvertiseData(
            serviceDataUuid: ezyServiceUuid,
            serviceData: _payload,
          ),
        );
        setState(() {
          _advertising = true;
          _encoding = 'Service data';
          _status = 'Advertising started using service data. Payload: 8 bytes.';
        });
        return;
      } catch (error) {
        serviceDataError = error;
      }
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        setState(
          () => _status = 'Bluetooth was turned off. Turn it on in Android settings, then try again.',
        );
        return;
      }

      Object? manufacturerError;
      try {
        await _startAdvertising(
          AdvertiseDataCore(
            manufacturerId: _testManufacturerId,
            manufacturerData: Uint8List.fromList(_payload),
          ),
          androidSettings: const AndroidAdvertiseSettings(
            advertiseResponseData: AndroidAdvertiseData(
              serviceUuids: [ezyServiceUuid],
            ),
          ),
        );
        setState(() {
          _advertising = true;
          _encoding = 'Manufacturer data';
          _status =
              'Service data failed ($serviceDataError). Advertising started using manufacturer data. Payload: 8 bytes.';
        });
        return;
      } catch (error) {
        manufacturerError = error;
      }
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        setState(
          () => _status = 'Bluetooth was turned off. Turn it on in Android settings, then try again.',
        );
        return;
      }

      try {
        final name = 'EZY:05:1:ABC234';
        final originalName = await _nativeBle.invokeMethod<String>(
          'getBluetoothName',
        );
        if (originalName == null) {
          throw StateError(
            'Android did not return the current Bluetooth name.',
          );
        }
        _originalBluetoothName = originalName;
        final renamed = await _nativeBle.invokeMethod<bool>(
          'setBluetoothName',
          {'name': name},
        );
        if (renamed != true) {
          throw StateError(
            'Android did not allow setting the temporary Bluetooth name.',
          );
        }
        await _startAdvertising(
          AndroidAdvertiseData(includeDeviceName: true),
          androidSettings: const AndroidAdvertiseSettings(
            advertiseResponseData: AndroidAdvertiseData(
              serviceUuids: [ezyServiceUuid],
            ),
          ),
        );
        setState(() {
          _advertising = true;
          _encoding = 'Device name';
          _status =
              'Service data failed ($serviceDataError); manufacturer data failed ($manufacturerError). Advertising started using the temporary phone name.';
        });
      } catch (error) {
        await _restoreBluetoothName();
        setState(() {
          _encoding = 'Not advertising';
          _status =
              'Advertising failed for all encodings. Service data: $serviceDataError. Manufacturer data: $manufacturerError. Device name: $error';
        });
      }
    } catch (error) {
      setState(() => _status = 'Advertising failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startSelectedEncoding(_BroadcastMode mode) async {
    switch (mode) {
      case _BroadcastMode.automatic:
        throw StateError('Select a specific encoding or Automatic fallback.');
      case _BroadcastMode.serviceData:
        await _startAdvertising(
          AndroidAdvertiseData(
            serviceDataUuid: ezyServiceUuid,
            serviceData: _payload,
          ),
        );
      case _BroadcastMode.manufacturerData:
        await _startAdvertising(
          AdvertiseDataCore(
            manufacturerId: _testManufacturerId,
            manufacturerData: Uint8List.fromList(_payload),
          ),
          androidSettings: const AndroidAdvertiseSettings(
            advertiseResponseData: AndroidAdvertiseData(
              serviceUuids: [ezyServiceUuid],
            ),
          ),
        );
      case _BroadcastMode.deviceName:
        final originalName = await _nativeBle.invokeMethod<String>(
          'getBluetoothName',
        );
        if (originalName == null) {
          throw StateError(
            'Android did not return the current Bluetooth name.',
          );
        }
        _originalBluetoothName = originalName;
        final renamed = await _nativeBle.invokeMethod<bool>(
          'setBluetoothName',
          {'name': 'EZY:05:1:ABC234'},
        );
        if (renamed != true) {
          throw StateError(
            'Android did not allow setting the temporary Bluetooth name.',
          );
        }
        await _startAdvertising(
          AndroidAdvertiseData(includeDeviceName: true),
          androidSettings: const AndroidAdvertiseSettings(
            advertiseResponseData: AndroidAdvertiseData(
              serviceUuids: [ezyServiceUuid],
            ),
          ),
        );
    }
  }

  Future<void> _startAdvertising(
    AdvertiseDataCore data, {
    AndroidAdvertiseSettings? androidSettings,
  }) async {
    final state = await _peripheral.start(
      advertiseData: data,
      androidSettings: androidSettings,
    );
    if (state == PeripheralBluetoothState.turnedOff) {
      throw StateError('Bluetooth is off. Turn it on in Android settings.');
    }
    if (state == PeripheralBluetoothState.unsupported) {
      throw StateError('This phone does not support BLE advertising.');
    }
    if (state != PeripheralBluetoothState.ready) {
      throw StateError('Peripheral returned state $state instead of ready.');
    }
  }

  Future<void> _stopBroadcast() async {
    setState(() => _busy = true);
    try {
      final state = await _peripheral.stop();
      await _restoreBluetoothName();
      setState(() {
        _advertising = false;
        _encoding = 'Not advertising';
        _status = state == PeripheralBluetoothState.ready
            ? 'Broadcast stopped.'
            : 'Broadcast stopped; peripheral returned state $state.';
      });
    } catch (error) {
      setState(() => _status = 'Could not stop broadcast: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBluetoothName() async {
    final oldName = _originalBluetoothName;
    if (oldName == null) return;
    try {
      await _nativeBle.invokeMethod<bool>('setBluetoothName', {
        'name': oldName,
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = 'Could not restore the phone Bluetooth name: $error',
        );
      }
    } finally {
      _originalBluetoothName = null;
    }
  }

  Future<void> _scan() async {
    if (_busy || _scanning) return;
    setState(() {
      _busy = true;
      _signals.clear();
      _status = 'Requesting Bluetooth permission…';
    });
    try {
      if (!await _explainAndRequestPermissions(advertise: false)) return;
      if (!await _bluetoothIsReady()) return;
      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          for (final result in results) {
            final signal = _decode(result);
            if (signal != null) {
              final key =
                  '${result.device.remoteId}:${signal.code}:${signal.encoding}';
              _signals[key] = signal;
            }
          }
          if (mounted) setState(() {});
        },
        onError: (Object error) {
          if (mounted) setState(() => _status = 'Scan failed: $error');
        },
      );
      setState(() {
        _scanning = true;
        _status = 'Scanning for the EZY service UUID for 10 seconds…';
      });
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        oneByOne: true,
      );
      final state = FlutterBluePlus.adapterStateNow;
      setState(() {
        _scanning = false;
        _status = state != BluetoothAdapterState.on
            ? 'Bluetooth was turned off during the scan.'
            : _signals.isEmpty
            ? 'Nothing found.'
            : 'Scan finished.';
      });
    } catch (error) {
      setState(() {
        _scanning = false;
        _status = 'Scan failed: $error';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  _FoundSignal? _decode(ScanResult result) {
    final advertisement = result.advertisementData;
    final serviceGuid = Guid(ezyServiceUuid);
    List<int>? bytes;
    String encoding;
    final serviceData = advertisement.serviceData[serviceGuid];
    if (serviceData != null) {
      bytes = serviceData;
      encoding = 'Service data';
    } else {
      final manufacturer = advertisement.manufacturerData[_testManufacturerId];
      if (manufacturer != null &&
          advertisement.serviceUuids.contains(serviceGuid)) {
        bytes = manufacturer;
        encoding = 'Manufacturer data';
      } else {
        final name = advertisement.advName.isNotEmpty
            ? advertisement.advName
            : result.device.advName;
        final match = RegExp(r'^EZY:(\d{2}):([1-5]):([A-Z2-9]{6})$')
            .firstMatch(name);
        if (!advertisement.serviceUuids.contains(serviceGuid) ||
            match == null) {
          return null;
        }
        return _FoundSignal(
          departmentId: int.parse(match.group(1)!),
          year: int.parse(match.group(2)!),
          code: match.group(3)!,
          rssi: result.rssi,
          time: result.timeStamp,
          encoding: 'Device name',
          payloadBytes: name.codeUnits.length,
        );
      }
    }
    if (bytes.length != 8) return null;
    final code = ascii.decode(bytes.sublist(2, 8), allowInvalid: true);
    if (!RegExp(r'^[A-Z2-9]{6}$').hasMatch(code)) return null;
    return _FoundSignal(
      departmentId: bytes[0],
      year: bytes[1],
      code: code,
      rssi: result.rssi,
      time: result.timeStamp,
      encoding: encoding,
      payloadBytes: bytes.length,
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    if (_scanning) FlutterBluePlus.stopScan();
    if (_advertising) _peripheral.stop();
    _restoreBluetoothName();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: GestureDetector(behavior: HitTestBehavior.opaque, onLongPress: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DesignPreviewScreen())), child: const Text('EZY BLE test'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Test payload: department 5, year 1, code ABC234 (8 bytes).',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<_BroadcastMode>(
          isExpanded: true,
          initialValue: _broadcastMode,
          decoration: const InputDecoration(labelText: 'Encoding to test'),
          items: const [
            DropdownMenuItem(
              value: _BroadcastMode.automatic,
              child: Text('Automatic fallback (service → manufacturer → name)', overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
            DropdownMenuItem(
              value: _BroadcastMode.serviceData,
              child: Text('Service data'),
            ),
            DropdownMenuItem(
              value: _BroadcastMode.manufacturerData,
              child: Text('Manufacturer data'),
            ),
            DropdownMenuItem(
              value: _BroadcastMode.deviceName,
              child: Text('Device name'),
            ),
          ],
          onChanged: _busy || _advertising
              ? null
              : (value) => setState(() => _broadcastMode = value!),
        ),
        const SizedBox(height: 12),
        Text('Encoding: $_encoding'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy || _advertising ? null : _broadcast,
          child: const Text('Broadcast code ABC234'),
        ),
        OutlinedButton(
          onPressed: _busy || !_advertising ? null : _stopBroadcast,
          child: const Text('Stop'),
        ),
        OutlinedButton(
          onPressed: _busy || _scanning ? null : _scan,
          child: const Text('Scan'),
        ),
        if (_busy || _scanning)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText(_status!),
          ),
        const Divider(),
        if (_signals.isEmpty && !_scanning) const Text('Nothing found.'),
        for (final signal in _signals.values)
          Card(
            child: ListTile(
              title: Text('${signal.encoding} • ${signal.code}'),
              subtitle: Text(
                'Class tag: department ${signal.departmentId}, year ${signal.year}\n'
                'RSSI: ${signal.rssi} dBm\n'
                'Time: ${signal.time.toLocal()}\n'
                'Payload size: ${signal.payloadBytes} bytes',
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Maximum payload size is not inferred from advertising start; compare the 8-byte payload on the receiving phone. This screen does not probe larger payload sizes.',
        ),
      ],
    ),
  );
}

class _FoundSignal {
  const _FoundSignal({
    required this.departmentId,
    required this.year,
    required this.code,
    required this.rssi,
    required this.time,
    required this.encoding,
    required this.payloadBytes,
  });

  final int departmentId;
  final int year;
  final String code;
  final int rssi;
  final DateTime time;
  final String encoding;
  final int payloadBytes;
}
