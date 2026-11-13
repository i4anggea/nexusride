import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:go_router/go_router.dart';
import 'package:nexusride/features/emergency/presentation/providers/emergency_provider.dart';
import 'package:nexusride/features/location/presentation/providers/ble_location_provider.dart';
import 'package:nexusride/shared/router/app_router.dart';

enum BleStatus { disconnected, connecting, connected, reconnecting, error }

final bleStatusProvider = StateProvider<BleStatus>(
  (_) => BleStatus.disconnected,
);

final bleBridgeProvider = Provider<BleBridge>((ref) {
  final bridge = BleBridge(ref);
  bridge.init();
  ref.onDispose(bridge.dispose);
  return bridge;
});

class BleBridge {
  final Ref _ref;
  final _service = FlutterBackgroundService();
  final List<StreamSubscription> _subs = [];
  Completer<void>? _readyCompleter;
  Completer<void>? _connectionCompleter;

  BleBridge(this._ref);

  void init() {
    _listen('ble_service_ready', (_) {
      final completer = _readyCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
    });

    _listen('location_update', (data) {
      if (data == null) return;
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      final speed = (data['speed'] as num?)?.toDouble();
      _ref.read(bleLocationProvider.notifier).update(lat, lng, speed);
    });

    _listen('impact_detected', (data) {
      if (data == null) return;
      final gForce = (data['g_force'] as num).toDouble();
      final loc = _ref.read(bleLocationProvider);
      unawaited(
        _handleImpact(
          gForce: gForce,
          latitude: loc?.latitude ?? 0,
          longitude: loc?.longitude ?? 0,
        ),
      );
    });

    _listen('ble_connected', (_) {
      _setStatus(BleStatus.connected);
      final completer = _connectionCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
    });
    _listen('ble_disconnected', (_) => _setStatus(BleStatus.disconnected));
    _listen('ble_reconnecting', (_) => _setStatus(BleStatus.reconnecting));
    _listen('ble_error', (data) {
      _setStatus(BleStatus.error);
      final completer = _connectionCompleter;
      if (completer != null && !completer.isCompleted) {
        final message = data?['message'] as String? ?? 'Error de conexión BLE.';
        completer.completeError(StateError(message));
      }
    });
  }

  Future<void> _handleImpact({
    required double gForce,
    required double latitude,
    required double longitude,
  }) async {
    final context = AppRouter.navigatorKey.currentContext;
    await _ref
        .read(emergencyNotifierProvider.notifier)
        .onImpactDetected(
          gForce: gForce,
          latitude: latitude,
          longitude: longitude,
        );
    if (context == null || !context.mounted) return;
    if (_ref.read(emergencyNotifierProvider) is EmergencyFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo registrar el accidente.')),
      );
      return;
    }
    context.go('/emergency');
  }

  Future<void> waitUntilReady() async {
    final completer = Completer<void>();
    _readyCompleter = completer;
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!completer.isCompleted && DateTime.now().isBefore(deadline)) {
      _service.invoke('ble_ping');
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (!completer.isCompleted) {
      _readyCompleter = null;
      throw TimeoutException('El servicio BLE no terminó de inicializarse.');
    }
    await completer.future;
    _readyCompleter = null;
  }

  Future<void> connectDevice(String mac) async {
    _setStatus(BleStatus.connecting);
    final completer = Completer<void>();
    _connectionCompleter = completer;
    _service.invoke('connect_device', {'mac': mac});
    try {
      await completer.future.timeout(const Duration(seconds: 35));
    } finally {
      if (identical(_connectionCompleter, completer)) {
        _connectionCompleter = null;
      }
    }
  }

  void resumeSavedDevice() {
    _setStatus(BleStatus.connecting);
    _service.invoke('resume_saved_device');
  }

  void disconnectDevice() => _service.invoke('disconnect_device');

  void stopService() => _service.invoke('stop_service');

  void _listen(String event, void Function(Map<String, dynamic>?) handler) {
    _subs.add(_service.on(event).listen(handler));
  }

  void _setStatus(BleStatus status) {
    _ref.read(bleStatusProvider.notifier).state = status;
  }

  void dispose() {
    final ready = _readyCompleter;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(StateError('Conexión BLE cancelada.'));
    }
    final connection = _connectionCompleter;
    if (connection != null && !connection.isCompleted) {
      connection.completeError(StateError('Conexión BLE cancelada.'));
    }
    for (final s in _subs) {
      s.cancel();
    }
  }
}
