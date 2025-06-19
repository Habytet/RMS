import 'package:hive/hive.dart';

part 'banquet_booking.g.dart';

@HiveType(typeId: 4)
class BanquetBooking extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String hallName;

  @HiveField(2)
  String slotLabel;

  @HiveField(3)
  String customerName;

  @HiveField(4)
  String phone;

  @HiveField(5)
  int pax;

  @HiveField(6)
  double amount;

  @HiveField(7)
  String menu;

  @HiveField(8)
  double totalAmount;

  @HiveField(9)
  double remainingAmount;

  @HiveField(10)
  String comments;

  @HiveField(11)
  DateTime? callbackTime;

  @HiveField(12)
  bool isDraft;

  BanquetBooking({
    required this.date,
    required this.hallName,
    required this.slotLabel,
    required this.customerName,
    required this.phone,
    required this.pax,
    required this.amount,
    required this.menu,
    required this.totalAmount,
    required this.remainingAmount,
    required this.comments,
    this.callbackTime,
    required this.isDraft,
  });
}