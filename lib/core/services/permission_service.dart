import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static const _deviceInfoChannel = MethodChannel('nexusride/device_info');

  static Future<bool> requestLocation(BuildContext context) async {
    var status = await Permission.locationWhenInUse.status;
    if (!_granted(status)) {
      status = await Permission.locationWhenInUse.request();
    }

    if (!_granted(status) && context.mounted) {
      _showSettingsIfPermanentlyDenied(context, status);
    }
    return _granted(status);
  }

  static Future<bool> hasLocationPermission() async =>
      _granted(await Permission.locationWhenInUse.status);

  static Future<bool> requestBluetooth(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    // Android 11 and earlier require location permission for BLE discovery.
    final sdkInt = await _androidSdkInt();
    if (sdkInt <= 30) {
      if (!context.mounted) return false;
      final location = await requestLocation(context);
      if (!location) return false;
      return true;
    }

    for (final permission in [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ]) {
      var status = await permission.status;
      if (!_granted(status)) status = await permission.request();
      if (!_granted(status)) {
        if (context.mounted) {
          _showSettingsIfPermanentlyDenied(context, status);
        }
        return false;
      }
    }

    return true;
  }

  static Future<bool> hasBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;
    final sdkInt = await _androidSdkInt();
    if (sdkInt <= 30) return hasLocationPermission();
    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    return _granted(scan) && _granted(connect);
  }

  static Future<int> _androidSdkInt() async =>
      await _deviceInfoChannel.invokeMethod<int>('androidSdkInt') ?? 0;

  static bool _granted(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  static void _showSettingsIfPermanentlyDenied(
    BuildContext context,
    PermissionStatus status,
  ) {
    if (!status.isPermanentlyDenied || !context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permiso requerido'),
        content: const Text(
          'NexusRide necesita este permiso para mostrar tu ubicación o buscar '
          'el módulo. Puedes habilitarlo en la configuración de la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }
}
