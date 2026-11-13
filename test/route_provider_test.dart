import 'package:flutter_test/flutter_test.dart';
import 'package:nexusride/features/location/presentation/providers/ble_location_provider.dart';
import 'package:nexusride/features/location/presentation/providers/route_provider.dart';

void main() {
  group('calculateDistanceKm', () {
    test('returns zero for the same point', () {
      expect(calculateDistanceKm(19.4326, -99.1332, 19.4326, -99.1332), 0);
    });

    test('calculates one degree of latitude accurately', () {
      expect(calculateDistanceKm(0, 0, 1, 0), closeTo(111.195, 0.01));
    });

    test('handles a crossing of the international date line', () {
      expect(calculateDistanceKm(0, 179.5, 0, -179.5), closeTo(111.195, 0.01));
    });
  });

  test('route adds distance between BLE locations while active', () {
    final route = RouteNotifier();
    addTearDown(route.dispose);

    route.startRoute();
    route.onLocationUpdate(
      const BleLocation(latitude: 0, longitude: 0, speed: 10),
    );
    route.onLocationUpdate(
      const BleLocation(latitude: 1, longitude: 0, speed: 12),
    );

    expect(route.state.currentSpeed, 12);
    expect(route.state.maxSpeed, 12);
    expect(route.state.totalDistance, closeTo(111.195, 0.01));
  });
}
