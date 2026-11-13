import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/emergency_provider.dart';
import 'package:nexusride/features/emergency/domain/models/incident_data.dart';
import 'package:nexusride/core/services/haptic_service.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});
  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  static const _totalSeconds = 30;
  int _remaining = _totalSeconds;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Vibración de alerta
    HapticFeedback.heavyImpact();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _sendAlert(); // Tiempo agotado → enviar automáticamente
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(emergencyNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    ref.listen(emergencyNotifierProvider, (_, next) {
      if (next is EmergencySending || next is EmergencyFailed) {
        _timer?.cancel();
      }
    });

    return Scaffold(
      backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.08),
      body: SafeArea(
        child: emergencyState.when(
          initial: () => _buildCountdown(context),
          sending: () => _buildSending(context),
          sent: (incident) => _buildSent(context, incident),
          cancelled: (incident) => _buildCancelled(context, incident),
          failed: (message) => _buildFailed(context, message),
        ),
      ),
    );
  }

  Widget _buildCountdown(BuildContext context) {
    final progress = _remaining / _totalSeconds;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Accidente detectado por el módulo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
          const Spacer(),
          // Countdown circular
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                color: Theme.of(context).colorScheme.error,
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$_remaining',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        )),
                Text('seg', style: Theme.of(context).textTheme.labelSmall),
              ]),
            ]),
          ),
          const SizedBox(height: 28),
          Text('¿Estás bien?',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Si no respondes, se notificará a tus contactos de emergencia con tu ubicación exacta.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          // Botón cancelar (grande, verde → acción principal)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onSecondaryContainer,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _cancelAlert,
              icon: const Icon(Icons.check_circle_outline, size: 22),
              label: const Text('Estoy bien, cancelar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _sendAlert,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Enviar alerta ahora'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSending(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Enviando alerta...'),
      ]),
    );
  }

  Widget _buildSent(BuildContext context, IncidentData incident) {
    final failedCount = incident.notifiedContacts
        .where((contact) => contact.status == 'failed')
        .length;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Alerta enviada', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
              failedCount == 0
                  ? 'Se procesaron los mensajes a tus contactos'
                  : '$failedCount mensaje(s) no se pudieron enviar',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          // Mapa mini con la ubicación
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.location_on,
                  color: Theme.of(context).colorScheme.error),
              Text(
                  '${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}',
                  style: Theme.of(context).textTheme.labelSmall),
            ]),
          ),
          const SizedBox(height: 16),
          // Lista de contactos con estado
          ...incident.notifiedContacts.map((c) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Text(c.initials)),
                  title: Text(c.name),
                  subtitle: Text(c.method),
                  trailing: _StatusChip(status: c.status),
                ),
              )),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Ver en mapa'),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelled(BuildContext context, IncidentData incident) {
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
              child: Icon(Icons.check,
                  size: 36,
                  color: Theme.of(context).colorScheme.onSecondaryContainer),
            ),
          ),
          const SizedBox(height: 20),
          Text('Todo en orden',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Alerta cancelada. El incidente fue registrado pero tus contactos no fueron notificados.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 28),
          // Resumen
          Card(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _InfoRow('Fuerza detectada',
                  '${incident.gForce.toStringAsFixed(1)} G'),
              const _InfoRow('Estado', 'Cancelado por usuario'),
            ]),
          )),
          const Spacer(),
          FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('Volver al mapa'),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.error_outline,
              size: 56, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 20),
          Text('No se completó la alerta',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('Volver al mapa'),
          ),
        ],
      ),
    );
  }

  void _sendAlert() {
    _timer?.cancel();
    HapticService.heavy();
    unawaited(ref.read(emergencyNotifierProvider.notifier).confirmAndSend());
  }

  void _cancelAlert() {
    _timer?.cancel();
    HapticService.success();
    unawaited(ref.read(emergencyNotifierProvider.notifier).cancel());
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'delivered' => 'Entregado',
      'sent' => 'Enviado',
      'failed' => 'Falló',
      _ => 'Pendiente',
    };
    final isOk = status == 'delivered' || status == 'sent';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOk
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 11,
            color: isOk
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          )),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
