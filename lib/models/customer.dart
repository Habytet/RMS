import 'package:hive/hive.dart';

part 'customer.g.dart';

@HiveType(typeId: 0)
class Customer extends HiveObject {
  @HiveField(0)
  int token;

  @HiveField(1)
  String name;

  @HiveField(2)
  String phone;

  @HiveField(3)
  int pax;

  @HiveField(4)
  DateTime registeredAt;

  @HiveField(5)
  DateTime? calledAt;

  @HiveField(6)
  int children;

  @HiveField(7)
  String? operator; // NEW FIELD

  Customer({
    required this.token,
    required this.name,
    required this.phone,
    required this.pax,
    required this.registeredAt,
    this.calledAt,
    this.children = 0,
    this.operator,
  });
}