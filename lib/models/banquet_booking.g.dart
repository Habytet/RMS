// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banquet_booking.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BanquetBookingAdapter extends TypeAdapter<BanquetBooking> {
  @override
  final int typeId = 4;

  @override
  BanquetBooking read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BanquetBooking(
      date: fields[0] as DateTime,
      hallName: fields[1] as String,
      slotLabel: fields[2] as String,
      customerName: fields[3] as String,
      phone: fields[4] as String,
      pax: fields[5] as int,
      amount: fields[6] as double,
      menu: fields[7] as String,
      totalAmount: fields[8] as double,
      remainingAmount: fields[9] as double,
      comments: fields[10] as String,
      callbackTime: fields[11] as DateTime?,
      isDraft: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BanquetBooking obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.hallName)
      ..writeByte(2)
      ..write(obj.slotLabel)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.phone)
      ..writeByte(5)
      ..write(obj.pax)
      ..writeByte(6)
      ..write(obj.amount)
      ..writeByte(7)
      ..write(obj.menu)
      ..writeByte(8)
      ..write(obj.totalAmount)
      ..writeByte(9)
      ..write(obj.remainingAmount)
      ..writeByte(10)
      ..write(obj.comments)
      ..writeByte(11)
      ..write(obj.callbackTime)
      ..writeByte(12)
      ..write(obj.isDraft);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BanquetBookingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
