// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_location.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingLocationAdapter extends TypeAdapter<PendingLocation> {
  @override
  final typeId = 0;

  @override
  PendingLocation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingLocation(
      latitude: (fields[0] as num).toDouble(),
      longitude: (fields[1] as num).toDouble(),
      speed: (fields[2] as num?)?.toDouble(),
      accuracy: (fields[3] as num?)?.toDouble(),
      recordedAt: fields[4] as DateTime,
      synced: fields[5] == null ? false : fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PendingLocation obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.speed)
      ..writeByte(3)
      ..write(obj.accuracy)
      ..writeByte(4)
      ..write(obj.recordedAt)
      ..writeByte(5)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingLocationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
