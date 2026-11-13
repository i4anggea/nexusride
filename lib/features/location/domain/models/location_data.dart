class LocationData {
  final double latitude;
  final double longitude;
  final double? speed;
  final double? accuracy;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.accuracy,
  });
}
