import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nexusride/features/location/domain/models/pending_location.dart';
import 'package:nexusride/hive_registrar.g.dart';
import 'package:nexusride/core/constants/app_constants.dart';

const _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const _locationUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
const _impactUuid = 'beb5483f-36e1-4688-b7f5-ea07361b26a9';
const _savedDeviceKey = 'nexusride.ble_device_mac';
const _savedDeviceStore = FlutterSecureStorage();

Future<void> initBleBackgroundService() async {
  final service = FlutterBackgroundService();
  if (await service.isRunning()) return;

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'nexusride_service',
      initialNotificationTitle: 'NexusRide activo',
      initialNotificationContent: 'Monitoreando en segundo plano',
      foregroundServiceNotificationId: 1,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onServiceStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

Future<void> resumeSavedBleDeviceService() async {
  final savedMac = await _savedDeviceStore.read(key: _savedDeviceKey);
  if (savedMac == null || savedMac.isEmpty) return;

  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke('resume_saved_device');
    return;
  }

  // The background isolate reads the saved address and reconnects on startup.
  await initBleBackgroundService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<PendingLocation>('pending_locations');

  BluetoothDevice? connectedDevice;
  StreamSubscription<List<int>>? locationSub;
  StreamSubscription<List<int>>? impactSub;
  String? targetMac;
  bool isConnecting = false;

  Future<void> disconnectCurrent() async {
    await locationSub?.cancel();
    await impactSub?.cancel();
    locationSub = null;
    impactSub = null;
    await connectedDevice?.disconnect();
    connectedDevice = null;
  }

  Future<void> connectAndSubscribe(String mac) async {
    if (isConnecting) return;
    isConnecting = true;
    try {
      await disconnectCurrent();
      connectedDevice = await _findAndConnect(mac);
      if (connectedDevice == null) {
        throw StateError('Dispositivo no encontrado');
      }

      final services = await connectedDevice!.discoverServices();
      final helmetService = services
          .where((s) => s.uuid.toString() == _serviceUuid)
          .firstOrNull;
      if (helmetService == null) {
        throw StateError('Servicio BLE del módulo no encontrado');
      }

      final locationChar = helmetService.characteristics
          .where((c) => c.uuid.toString() == _locationUuid)
          .firstOrNull;
      if (locationChar != null) {
        await locationChar.setNotifyValue(true);
        locationSub = locationChar.onValueReceived.listen(
          (bytes) => _onLocation(bytes, service),
        );
      }

      final impactChar = helmetService.characteristics
          .where((c) => c.uuid.toString() == _impactUuid)
          .firstOrNull;
      if (impactChar != null) {
        await impactChar.setNotifyValue(true);
        impactSub = impactChar.onValueReceived.listen(
          (bytes) => _onImpact(bytes, service),
        );
      }

      await _savedDeviceStore.write(key: _savedDeviceKey, value: mac);
      service.invoke('ble_connected', {
        'mac': mac,
        'name': connectedDevice!.platformName,
      });
    } catch (error) {
      await disconnectCurrent();
      service.invoke('ble_error', {'message': error.toString()});
    } finally {
      isConnecting = false;
    }
  }

  service.on('connect_device').listen((data) async {
    targetMac = data?['mac'] as String?;
    if (targetMac == null) return;
    await connectAndSubscribe(targetMac!);
  });

  service.on('ble_ping').listen((_) {
    service.invoke('ble_service_ready', {});
  });

  service.on('resume_saved_device').listen((_) async {
    targetMac ??= await _savedDeviceStore.read(key: _savedDeviceKey);
    if (targetMac != null) await connectAndSubscribe(targetMac!);
  });

  service.on('disconnect_device').listen((_) async {
    targetMac = null;
    await _savedDeviceStore.delete(key: _savedDeviceKey);
    await disconnectCurrent();
    service.invoke('ble_disconnected', {});
  });

  service.on('stop_service').listen((_) async {
    await disconnectCurrent();
    await service.stopSelf();
  });

  targetMac = await _savedDeviceStore.read(key: _savedDeviceKey);
  if (targetMac != null && targetMac!.isNotEmpty) {
    unawaited(connectAndSubscribe(targetMac!));
  }

  Timer.periodic(const Duration(seconds: 10), (_) async {
    if (!isConnecting &&
        targetMac != null &&
        (connectedDevice == null || !connectedDevice!.isConnected)) {
      service.invoke('ble_reconnecting', {});
      await connectAndSubscribe(targetMac!);
    }
  });
}

void _onLocation(List<int> bytes, ServiceInstance service) async {
  final raw = String.fromCharCodes(bytes);
  final parts = raw.split(',');
  if (parts.length < 2) return;

  final lat = double.tryParse(parts[0]);
  final lng = double.tryParse(parts[1]);
  final speed = parts.length > 2 ? double.tryParse(parts[2]) : null;
  if (lat == null || lng == null) return;

  service.invoke('location_update', {'lat': lat, 'lng': lng, 'speed': speed});

  final box = Hive.box<PendingLocation>('pending_locations');
  await box.add(
    PendingLocation(
      latitude: lat,
      longitude: lng,
      speed: speed,
      recordedAt: DateTime.now(),
    ),
  );
}

void _onImpact(List<int> bytes, ServiceInstance service) {
  final gForce = double.tryParse(String.fromCharCodes(bytes));
  if (gForce == null) return;
  if (gForce < AppConstants.accidentGForceThreshold) return;
  service.invoke('impact_detected', {'g_force': gForce});
}

Future<BluetoothDevice?> _findAndConnect(String mac) async {
  if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
  final targetCompleter = Completer<ScanResult>();
  final scanSubscription = FlutterBluePlus.scanResults
      .expand((results) => results)
      .listen((result) {
        if (result.device.remoteId.str == mac && !targetCompleter.isCompleted) {
          targetCompleter.complete(result);
        }
      });

  try {
    await FlutterBluePlus.startScan(
      withRemoteIds: [mac],
      timeout: const Duration(seconds: 10),
    );
    final target = await targetCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException(
        'No se volvió a detectar el módulo BLE seleccionado.',
      ),
    );
    await FlutterBluePlus.stopScan();
    await target.device.connect();
    return target.device;
  } finally {
    if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
    await scanSubscription.cancel();
  }
}
