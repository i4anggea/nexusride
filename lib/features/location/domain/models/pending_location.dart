import 'package:hive_ce/hive.dart';

part 'pending_location.g.dart';

@HiveType(typeId: 0)
class PendingLocation extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final double? speed;

  @HiveField(3)
  final double? accuracy;

  @HiveField(4)
  final DateTime recordedAt;

  @HiveField(5)
  bool synced;

  PendingLocation({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.accuracy,
    required this.recordedAt,
    this.synced = false,
  });
}
