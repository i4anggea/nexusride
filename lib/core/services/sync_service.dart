import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/location/domain/models/pending_location.dart';
import 'connectivity_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService();

  // Escuchar cuando vuelve la conexión y disparar sync automático
  ref.listen(connectivityStreamProvider, (previous, next) {
    final wasOffline = previous?.value == false;
    final isNowOnline = next.value == true;

    if (wasOffline && isNowOnline) {
      unawaited(service.flush()); // volvió la conexión → sincronizar todo
    }
  });

  return service;
});

class SyncService {
  static const _boxName = 'pending_locations';
  bool _isSyncing = false;

  Box<PendingLocation> get _box => Hive.box<PendingLocation>(_boxName);

  // ── Guardar localmente cuando no hay internet ──────────
  Future<void> saveLocal(PendingLocation location) async {
    await _box.add(location);
  }

  // ── Cuántos registros están esperando sincronización ──
  int get pendingCount => _box.values.where((l) => !l.synced).length;

  // ── Subir todo lo pendiente a Supabase ────────────────
  Future<bool> flush() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final pending = _box.values.where((l) => !l.synced).toList();

      if (pending.isEmpty) return true;

      // Subir en lotes de 50 para no saturar la API
      const batchSize = 50;
      for (var i = 0; i < pending.length; i += batchSize) {
        final batch = pending.skip(i).take(batchSize).toList();

        await Supabase.instance.client
            .from('gps_locations')
            .insert(
              batch
                  .map(
                    (loc) => {
                      'user_id': user.id,
                      'latitude': loc.latitude,
                      'longitude': loc.longitude,
                      'speed': loc.speed,
                      'accuracy': loc.accuracy,
                      'recorded_at': loc.recordedAt.toIso8601String(),
                    },
                  )
                  .toList(),
            );

        // Marcar como sincronizados
        for (final loc in batch) {
          loc.synced = true;
          await loc.save();
        }
      }

      // Limpiar los ya sincronizados para no crecer indefinidamente
      await _cleanSynced();
      return pendingCount == 0;
    } catch (e) {
      // Si falla la subida, quedan en Hive para el próximo intento
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  // ── Eliminar los ya sincronizados de Hive ─────────────
  Future<void> _cleanSynced() async {
    final syncedKeys = _box.values
        .where((l) => l.synced)
        .map((l) => l.key)
        .toList();

    await _box.deleteAll(syncedKeys);
  }

  // ── Limpiar todo (útil al hacer logout) ───────────────
}
