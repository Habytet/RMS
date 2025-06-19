// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppUserAdapter extends TypeAdapter<AppUser> {
  @override
  final int typeId = 1;

  @override
  AppUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppUser(
      username: fields[0] as String,
      password: fields[1] as String,
      podiumEnabled: fields[2] as bool,
      waiterEnabled: fields[3] as bool,
      customerEnabled: fields[4] as bool,
      banquetBookingEnabled: fields[5] as bool,
      banquetReportsEnabled: fields[6] as bool,
      queueReportsEnabled: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AppUser obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.username)
      ..writeByte(1)
      ..write(obj.password)
      ..writeByte(2)
      ..write(obj.podiumEnabled)
      ..writeByte(3)
      ..write(obj.waiterEnabled)
      ..writeByte(4)
      ..write(obj.customerEnabled)
      ..writeByte(5)
      ..write(obj.banquetBookingEnabled)
      ..writeByte(6)
      ..write(obj.banquetReportsEnabled)
      ..writeByte(7)
      ..write(obj.queueReportsEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
