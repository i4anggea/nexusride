import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nexusride/core/services/permission_service.dart';
import '../providers/device_provider.dart';
import '../providers/ble_bridge_provider.dart';

class DeviceScreen extends ConsumerStatefulWidget {
  const DeviceScreen({super.key});
  @override
  ConsumerState<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DeviceScreen> {
  int _step = 0; // 0: instrucciones, 1: escaneando, 2: conectado

  @override
  Widget build(BuildContext context) {
    final scanResults = ref.watch(bleScanResultsProvider);
    final deviceStatus = ref.watch(deviceStatusProvider);
    final bleStatus = ref.watch(bleStatusProvider);
    final connectionState = ref.watch(deviceScanProvider);
    ref.listen(bleStatusProvider, (_, status) {
      ref.read(deviceStatusProvider.notifier).state = switch (status) {
        BleStatus.connected => DeviceStatus.connected,
        BleStatus.connecting ||
        BleStatus.reconnecting => DeviceStatus.connecting,
        BleStatus.disconnected || BleStatus.error => DeviceStatus.disconnected,
      };
    });

    if (deviceStatus == DeviceStatus.connected ||
        bleStatus == BleStatus.connected) {
      _step = 2;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar módulo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: [
        _StepInstructions(onNext: _startScan),
        _StepScan(
          results: scanResults.value ?? [],
          errorMessage: connectionState.hasError
              ? 'No se pudo conectar: ${connectionState.error}'
              : bleStatus == BleStatus.error
              ? 'No se encontró el módulo. Vuelve a buscarlo.'
              : null,
        ),
        const _StepConnected(),
      ][_step.clamp(0, 2)],
    );
  }

  Future<void> _startScan() async {
    if (!await PermissionService.requestBluetooth(context) || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se necesitan permisos para buscar el módulo.'),
          ),
        );
      }
      return;
    }
    setState(() => _step = 1);
    await ref.read(deviceScanProvider.notifier).startScan();
  }
}

// --- Paso 1: Instrucciones ---
class _StepInstructions extends StatelessWidget {
  final VoidCallback onNext;
  const _StepInstructions({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.bluetooth_searching,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Enciende el módulo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Enciende el módulo. El firmware anuncia NexusRide automáticamente; no hace falta mantener pulsado el botón SOS ni activar un modo de emparejamiento.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          // Pasos
          const _InstructionStep(
            number: 1,
            done: true,
            text:
                'Enciende el módulo y confirma en el monitor serial que aparece “BLE iniciado”.',
          ),
          const _InstructionStep(
            number: 2,
            text: 'Activa Bluetooth en el teléfono y acerca el módulo.',
          ),
          const _InstructionStep(
            number: 3,
            text:
                'Toca “Buscar módulo”; NexusRide buscará el servicio BLE esperado.',
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.search),
            label: const Text('Buscar módulo'),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final int number;
  final String text;
  final bool done;
  const _InstructionStep({
    required this.number,
    required this.text,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: done
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    )
                  : Text(
                      '$number',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// --- Paso 2: Escaneo ---
class _StepScan extends ConsumerWidget {
  final List<ScanResult> results;
  final String? errorMessage;
  const _StepScan({required this.results, this.errorMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // startScan filters by the advertised service UUID; the scan-response name
    // may be absent from the scan result on some Android devices.
    final helmets = results;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (errorMessage != null) ...[
            Text(
              errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                'Buscando dispositivos BLE...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...helmets.map(
            (r) => _DeviceTile(
              result: r,
              onTap: () =>
                  ref.read(deviceScanProvider.notifier).connect(r.device),
            ),
          ),
          if (helmets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Buscando... asegúrate de que el LED azul parpadee.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onTap;

  const _DeviceTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.shield_outlined),
        title: Text(
          result.device.platformName.isEmpty
              ? 'Módulo NexusRide'
              : result.device.platformName,
        ),
        subtitle: Text('Señal: ${result.rssi} dBm'),
        trailing: FilledButton.tonal(
          onPressed: onTap,
          child: const Text('Conectar'),
        ),
      ),
    );
  }
}

// --- Paso 3: Conectado ---
// Reemplaza _StepConnected.build() con valores fijos por ahora:
class _StepConnected extends StatelessWidget {
  const _StepConnected();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 36,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Módulo conectado',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tu casco está listo. La app detectará accidentes automáticamente.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 28),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Ir al mapa'),
          ),
        ],
      ),
    );
  }
}
