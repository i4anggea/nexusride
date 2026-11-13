import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../emergency/domain/models/incident_data.dart';

// ── Estado con método when manual ─────────────────────────
abstract class EmergencyState {
  const EmergencyState();

  T when<T>({
    required T Function() initial,
    required T Function() sending,
    required T Function(IncidentData) sent,
    required T Function(IncidentData) cancelled,
    required T Function(String) failed,
  }) {
    final s = this;
    if (s is EmergencyInitial) return initial();
    if (s is EmergencySending) return sending();
    if (s is EmergencySent) return sent(s.incident);
    if (s is EmergencyCancelled) return cancelled(s.incident);
    if (s is EmergencyFailed) return failed(s.message);
    throw StateError('Estado desconocido: $s');
  }
}

class EmergencyInitial extends EmergencyState {
  const EmergencyInitial();
}

class EmergencySending extends EmergencyState {
  const EmergencySending();
}

class EmergencySent extends EmergencyState {
  final IncidentData incident;
  const EmergencySent(this.incident);
}

class EmergencyCancelled extends EmergencyState {
  final IncidentData incident;
  const EmergencyCancelled(this.incident);
}

class EmergencyFailed extends EmergencyState {
  final String message;
  const EmergencyFailed(this.message);
}

// ── Provider ───────────────────────────────────────────────
final emergencyNotifierProvider =
    StateNotifierProvider<EmergencyNotifier, EmergencyState>(
  (_) => EmergencyNotifier(), // sin ref
);

class EmergencyNotifier extends StateNotifier<EmergencyState> {
  EmergencyNotifier() : super(const EmergencyInitial());

  String? _incidentId;
  Future<void>? _incidentCreation;
  bool _isSubmitting = false;
  double _gForce = 0;
  double _lat = 0;
  double _lng = 0;

  Future<void> onImpactDetected({
    required double gForce,
    required double latitude,
    required double longitude,
  }) {
    _gForce = gForce;
    _lat = latitude;
    _lng = longitude;
    _incidentId = null;
    _isSubmitting = false;
    state = const EmergencyInitial();
    _incidentCreation = _createPendingIncident();
    return _incidentCreation!;
  }

  Future<void> _createPendingIncident() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw StateError('No hay una sesión activa.');

      final res = await Supabase.instance.client
          .from('incidents')
          .insert({
            'user_id': user.id,
            'latitude': _lat,
            'longitude': _lng,
            'g_force': _gForce,
            'status': 'detected',
          })
          .select('id')
          .single();

      _incidentId = res['id'] as String;
    } catch (_) {
      state = const EmergencyFailed(
        'No se pudo registrar el incidente. Comprueba la conexión e inténtalo de nuevo.',
      );
    }
  }

  Future<void> confirmAndSend() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    state = const EmergencySending();
    try {
      await _incidentCreation;
      final incidentId = _incidentId;
      if (incidentId == null) {
        throw StateError('El incidente no está disponible.');
      }

      await Supabase.instance.client.functions.invoke(
        'notify-emergency',
        body: {'incident_id': incidentId},
      );

      final res = await Supabase.instance.client
          .from('incidents')
          .select(
              '*, incident_notifications(*, emergency_contacts(name, phone))')
          .eq('id', incidentId)
          .single();
      if (res['status'] == 'detected') {
        throw StateError('El servicio no confirmó el envío de la alerta.');
      }
      state = EmergencySent(IncidentData.fromJson(res));
    } catch (_) {
      state = const EmergencyFailed(
        'No se pudo enviar la alerta. El incidente quedó registrado; vuelve a intentarlo o llama a emergencias.',
      );
    } finally {
      _isSubmitting = false;
    }
  }

  Future<void> cancel() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    try {
      await _incidentCreation;
      final incidentId = _incidentId;
      if (incidentId == null) {
        throw StateError('El incidente no está disponible.');
      }

      await Supabase.instance.client.from('incidents').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', incidentId);

      state = EmergencyCancelled(IncidentData(
        id: incidentId,
        gForce: _gForce,
        latitude: _lat,
        longitude: _lng,
        status: 'cancelled',
        notifiedContacts: [],
      ));
    } catch (_) {
      state = const EmergencyFailed(
        'No se pudo cancelar el incidente en el servidor. Comprueba la conexión.',
      );
    } finally {
      _isSubmitting = false;
    }
  }
}
