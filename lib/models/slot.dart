import 'package:hive/hive.dart';

part 'slot.g.dart';

@HiveType(typeId: 3)
class Slot extends HiveObject {
  @HiveField(0)
  String hallName;

  @HiveField(1)
  String label;

  Slot({required this.hallName, required this.label});
}