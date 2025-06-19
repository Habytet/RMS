import 'package:hive/hive.dart';

part 'hall.g.dart';

@HiveType(typeId: 2)
class Hall extends HiveObject {
  @HiveField(0)
  String name;

  Hall({required this.name});
}