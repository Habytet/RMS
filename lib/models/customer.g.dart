// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 0;

  @override
  Customer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Customer(
      token: fields[0] as int,
      name: fields[1] as String,
      phone: fields[2] as String,
      pax: fields[3] as int,
      registeredAt: fields[4] as DateTime,
      calledAt: fields[5] as DateTime?,
      children: fields[6] as int,
      operator: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.token)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.pax)
      ..writeByte(4)
      ..write(obj.registeredAt)
      ..writeByte(5)
      ..write(obj.calledAt)
      ..writeByte(6)
      ..write(obj.children)
      ..writeByte(7)
      ..write(obj.operator);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
