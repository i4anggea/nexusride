import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nexusride/core/services/connectivity_service.dart';
import 'package:nexusride/core/services/sync_service.dart';
import 'package:nexusride/features/location/domain/models/location_data.dart';
import 'package:nexusride/features/location/domain/models/pending_location.dart';

final locationStreamProvider = StreamProvider<LocationData>((ref) async* {
  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw StateError('Se necesita permiso de ubicación para usar el GPS.');
  }
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw StateError('Activa los servicios de ubicación del dispositivo.');
  }

  final syncService = ref.read(syncServiceProvider);

  final posStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  );

  await for (final pos in posStream) {
    final loc = LocationData(
      latitude: pos.latitude,
      longitude: pos.longitude,
      speed: pos.speed * 3.6,
      accuracy: pos.accuracy,
    );

    yield loc;

    final isOnline = await checkConnectivity();

    if (isOnline) {
      final success = await _uploadToSupabase(loc);
      if (!success) {
        await syncService.saveLocal(
          PendingLocation(
            latitude: loc.latitude,
            longitude: loc.longitude,
            speed: loc.speed,
            accuracy: loc.accuracy,
            recordedAt: DateTime.now(),
          ),
        );
      }
    } else {
      await syncService.saveLocal(
        PendingLocation(
          latitude: loc.latitude,
          longitude: loc.longitude,
          speed: loc.speed,
          accuracy: loc.accuracy,
          recordedAt: DateTime.now(),
        ),
      );
    }
  }
});

Future<bool> _uploadToSupabase(LocationData loc) async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    await Supabase.instance.client.from('gps_locations').insert({
      'user_id': user.id,
      'latitude': loc.latitude,
      'longitude': loc.longitude,
      'speed': loc.speed,
      'accuracy': loc.accuracy,
    });
    return true;
  } catch (_) {
    return false;
  }
}

final routePolylineProvider = Provider<Set<Polyline>>((ref) => <Polyline>{});
