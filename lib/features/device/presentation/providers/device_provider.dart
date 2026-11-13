import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nexusride/features/location/presentation/providers/ble_location_provider.dart';
import 'package:nexusride/features/device/presentation/providers/ble_bridge_provider.dart';
import 'package:nexusride/shared/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nexusride/features/emergency/presentation/providers/emergency_provider.dart';
import 'package:nexusride/core/services/ble_background_service.dart';

const _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const _locationUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
const _impactUuid = 'beb5483f-36e1-4688-b7f5-ea07361b26a9';

enum DeviceStatus { disconnected, scanning, connecting, connected }

final deviceStatusProvider = StateProvider<DeviceStatus>(
  (_) => DeviceStatus.disconnected,
);

final bleScanResultsProvider = StreamProvider<List<ScanResult>>(
  (ref) => FlutterBluePlus.scanResults,
);

final deviceScanProvider =
    StateNotifierProvider<DeviceScanNotifier, AsyncValue<void>>(
      (ref) => DeviceScanNotifier(ref),
    );

class DeviceScanNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _impactSub;
  StreamSubscription<List<int>>? _locationSub;

  DeviceScanNotifier(this._ref) : super(const AsyncData(null));

  // ── Iniciar escaneo BLE ──────────────────────────────
  Future<void> startScan() async {
    _ref.read(deviceStatusProvider.notifier).state = DeviceStatus.scanning;
    state = const AsyncLoading();
    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(_serviceUuid)],
        timeout: const Duration(seconds: 10),
      );
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      _ref.read(deviceStatusProvider.notifier).state =
          DeviceStatus.disconnected;
      state = AsyncError(error, stackTrace);
    }
  }

  // ── Conectar al dispositivo seleccionado ─────────────
  Future<void> connect(BluetoothDevice device) async {
    _ref.read(deviceStatusProvider.notifier).state = DeviceStatus.connecting;
    state = const AsyncLoading();

    try {
      await FlutterBluePlus.stopScan();

      if (Platform.isAndroid) {
        // Attach to events before the background isolate is started.
        final bridge = _ref.read(bleBridgeProvider);
        await initBleBackgroundService();
        await bridge.waitUntilReady();
        await bridge.connectDevice(device.remoteId.str);
        await _saveDevice(device);
        _ref.read(deviceStatusProvider.notifier).state = DeviceStatus.connected;
        state = const AsyncData(null);
        return;
      }

      await device.connect();
      _device = device;

      // Descubrir servicios BLE del módulo
      final services = await device.discoverServices();
      final helmetService = services
          .where((s) => s.uuid.toString() == _serviceUuid)
          .firstOrNull;

      if (helmetService == null) {
        throw StateError('El módulo no ofrece el servicio BLE esperado.');
      }

      // Suscribirse a característica de ubicación
      final locationChar = helmetService.characteristics
          .where((c) => c.uuid.toString() == _locationUuid)
          .firstOrNull;

      if (locationChar != null) {
        await locationChar.setNotifyValue(true);
        _locationSub = locationChar.onValueReceived.listen(_onLocationReceived);
      }

      // Suscribirse a característica de impacto
      final impactChar = helmetService.characteristics
          .where((c) => c.uuid.toString() == _impactUuid)
          .firstOrNull;

      if (impactChar != null) {
        await impactChar.setNotifyValue(true);
        _impactSub = impactChar.onValueReceived.listen(_onImpactReceived);
      }

      await _saveDevice(device);
      _ref.read(deviceStatusProvider.notifier).state = DeviceStatus.connected;
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      await _device?.disconnect();
      _device = null;
      _ref.read(deviceStatusProvider.notifier).state =
          DeviceStatus.disconnected;
      state = AsyncError(error, stackTrace);
    }
  }

  // ── Recibir ubicación GPS del módulo ─────────────────
  // Formato esperado del ESP32: "lat,lng,speed"
  void _onLocationReceived(List<int> bytes) {
    final raw = String.fromCharCodes(bytes);
    final parts = raw.split(',');
    if (parts.length < 2) return;

    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    final speed = parts.length > 2 ? double.tryParse(parts[2]) : null;
    if (lat == null || lng == null) return;

    _ref.read(bleLocationProvider.notifier).update(lat, lng, speed);
  }

  // ── Recibir señal de impacto del acelerómetro ────────
  // Formato esperado del ESP32: "gforce" como string float
  void _onImpactReceived(List<int> bytes) {
    final raw = String.fromCharCodes(bytes);
    final gForce = double.tryParse(raw);
    if (gForce == null) return;
    if (gForce < 4.0) return; // umbral mínimo

    final loc = _ref.read(bleLocationProvider);
    unawaited(
      _handleImpact(
        gForce: gForce,
        latitude: loc?.latitude ?? 0,
        longitude: loc?.longitude ?? 0,
      ),
    );
  }

  Future<void> _handleImpact({
    required double gForce,
    required double latitude,
    required double longitude,
  }) async {
    await _ref
        .read(emergencyNotifierProvider.notifier)
        .onImpactDetected(
          gForce: gForce,
          latitude: latitude,
          longitude: longitude,
        );
    if (_ref.read(emergencyNotifierProvider) is EmergencyFailed) return;
    AppRouter.navigatorKey.currentContext?.go('/emergency');
  }

  // ── Guardar dispositivo en Supabase ──────────────────
  Future<void> _saveDevice(BluetoothDevice device) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from('devices').upsert({
        'user_id': user.id,
        'mac_address': device.remoteId.str,
        'name': device.platformName,
        'last_seen': DateTime.now().toIso8601String(),
        'is_active': true,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _impactSub?.cancel();
    _locationSub?.cancel();
    _device?.disconnect();
    super.dispose();
  }
}
