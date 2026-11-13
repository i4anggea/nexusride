import 'package:flutter_riverpod/flutter_riverpod.dart';

class BleLocation {
  final double latitude;
  final double longitude;
  final double? speed;
  const BleLocation({
    required this.latitude,
    required this.longitude,
    this.speed,
  });
}

class BleLocationNotifier extends StateNotifier<BleLocation?> {
  BleLocationNotifier() : super(null);

  void update(double lat, double lng, double? speed) {
    state = BleLocation(latitude: lat, longitude: lng, speed: speed);
  }
}

final bleLocationProvider =
    StateNotifierProvider<BleLocationNotifier, BleLocation?>(
  (_) => BleLocationNotifier(),
);
