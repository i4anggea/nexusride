import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nexusride/features/location/domain/models/pending_location.dart';
import 'package:nexusride/hive_registrar.g.dart';

void main() {
  late Directory storageDirectory;

  setUp(() async {
    storageDirectory = await Directory.systemTemp.createTemp('nexusride-hive-');
    Hive.init(storageDirectory.path);
    Hive.registerAdapters();
  });

  tearDown(() async {
    await Hive.close();
    await storageDirectory.delete(recursive: true);
  });

  test('pending locations survive closing and reopening their box', () async {
    final capturedAt = DateTime.utc(2026, 9, 30, 12);
    final box = await Hive.openBox<PendingLocation>('pending_locations');
    await box.add(
      PendingLocation(
        latitude: 19.4326,
        longitude: -99.1332,
        speed: 8.5,
        accuracy: 3,
        recordedAt: capturedAt,
      ),
    );
    await box.close();

    final reopened = await Hive.openBox<PendingLocation>('pending_locations');
    final restored = reopened.getAt(0)!;

    expect(restored.latitude, 19.4326);
    expect(restored.longitude, -99.1332);
    expect(restored.speed, 8.5);
    expect(restored.accuracy, 3);
    expect(restored.recordedAt, capturedAt);
    expect(restored.synced, isFalse);
  });
}
