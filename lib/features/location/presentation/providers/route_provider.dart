import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexusride/features/location/presentation/providers/ble_location_provider.dart';

enum RouteStatus { idle, active, paused }

class RouteState {
  final RouteStatus status;
  final DateTime? startedAt;
  final double totalDistance;
  final double maxSpeed;
  final double currentSpeed;
  final int duration;

  const RouteState({
    this.status = RouteStatus.idle,
    this.startedAt,
    this.totalDistance = 0,
    this.maxSpeed = 0,
    this.currentSpeed = 0,
    this.duration = 0,
  });

  RouteState copyWith({
    RouteStatus? status,
    DateTime? startedAt,
    double? totalDistance,
    double? maxSpeed,
    double? currentSpeed,
    int? duration,
  }) =>
      RouteState(
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        totalDistance: totalDistance ?? this.totalDistance,
        maxSpeed: maxSpeed ?? this.maxSpeed,
        currentSpeed: currentSpeed ?? this.currentSpeed,
        duration: duration ?? this.duration,
      );

  bool get isActive => status == RouteStatus.active;
}

final routeProvider = StateNotifierProvider<RouteNotifier, RouteState>(
  (_) => RouteNotifier(),
);

class RouteNotifier extends StateNotifier<RouteState> {
  RouteNotifier() : super(const RouteState());

  Timer? _timer;
  BleLocation? _lastLocation;

  void startRoute() {
    state = RouteState(
      status: RouteStatus.active,
      startedAt: DateTime.now(),
    );
    _startTimer();
  }

  void stopRoute() {
    _timer?.cancel();
    _lastLocation = null;
    state = state.copyWith(status: RouteStatus.idle);
  }

  void pauseRoute() {
    _timer?.cancel();
    state = state.copyWith(status: RouteStatus.paused);
  }

  void resumeRoute() {
    state = state.copyWith(status: RouteStatus.active);
    _startTimer();
  }

  // Llamado cada vez que llega una nueva ubicación BLE
  void onLocationUpdate(BleLocation loc) {
    if (!state.isActive) return;

    final speed = loc.speed ?? 0;

    // Calcular distancia desde la última posición (Haversine simplificado)
    double distanceDelta = 0;
    if (_lastLocation != null) {
      distanceDelta = calculateDistanceKm(
        _lastLocation!.latitude,
        _lastLocation!.longitude,
        loc.latitude,
        loc.longitude,
      );
    }
    _lastLocation = loc;

    state = state.copyWith(
      currentSpeed: speed,
      maxSpeed: speed > state.maxSpeed ? speed : state.maxSpeed,
      totalDistance: state.totalDistance + distanceDelta,
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isActive) return;
      state = state.copyWith(duration: state.duration + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Great-circle distance in kilometres between two latitude/longitude pairs.
double calculateDistanceKm(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const earthRadiusKm = 6371.0088;
  final lat1 = _degreesToRadians(latitude1);
  final lat2 = _degreesToRadians(latitude2);
  final deltaLat = lat2 - lat1;
  final deltaLng = _degreesToRadians(longitude2 - longitude1);

  final a = (math.sin(deltaLat / 2) * math.sin(deltaLat / 2)) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(deltaLng / 2) *
          math.sin(deltaLng / 2);
  final clampedA = a.clamp(0.0, 1.0);
  return 2 * earthRadiusKm * math.asin(math.sqrt(clampedA));
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;
